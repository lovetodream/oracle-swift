import ODPIC

internal struct OracleStatement {
    private var handle: OpaquePointer?
    private let connection: OracleConnection

    internal init(query: String, on connection: OracleConnection) throws {
        guard let cHandle = connection.handle else {
            throw OracleError(reason: .noHandle, message: "The db handle is not available, the connection is most likely already closed")
        }
        self.connection = connection
        guard dpiConn_prepareStmt(cHandle, 0, query, UInt32(query.count), nil, 0, &handle) == DPI_SUCCESS else {
            connection.logger.debug("Failed to prepare statement")
            throw OracleError.getLast(for: connection)
        }
        connection.logger.debug("Statement successfully prepared")
    }

    internal func bind(_ binds: [OracleData]) throws {
        for (i, bind) in binds.enumerated() {
            let i = UInt32(i + 1)
            switch bind {
            case .integer(let value):
                var data = dpiData(isNull: 0, value: dpiDataBuffer(asInt64: Int64(value)))
                guard dpiStmt_bindValueByPos(handle, i, dpiNativeTypeNum(DPI_NATIVE_TYPE_INT64), &data) == DPI_SUCCESS else {
                    throw OracleError.getLast(for: connection)
                }
            case .float(let value):
                var data = dpiData(isNull: 0, value: dpiDataBuffer(asDouble: value))
                guard dpiStmt_bindValueByPos(handle, i, dpiNativeTypeNum(DPI_NATIVE_TYPE_DOUBLE), &data) == DPI_SUCCESS else {
                    throw OracleError.getLast(for: connection)
                }
            case .text(let value):
                try value.withCString {
                    var data = dpiData(isNull: 0, value: dpiDataBuffer(asString: UnsafeMutablePointer(mutating: $0)))
                    guard dpiStmt_bindValueByPos(handle, i, dpiNativeTypeNum(DPI_NATIVE_TYPE_BYTES), &data) == DPI_SUCCESS else {
                        throw OracleError.getLast(for: connection)
                    }
                }
            case .blob(var value):
                try value.withUnsafeMutableReadableBytes { pointer in
                    var data = dpiData(isNull: 0, value: dpiDataBuffer(asRaw: pointer.baseAddress))
                    guard dpiStmt_bindValueByPos(handle, i, dpiNativeTypeNum(DPI_NATIVE_TYPE_LOB), &data) == DPI_SUCCESS else {
                        throw OracleError.getLast(for: connection)
                    }
                }
            case .null:
                var data = dpiData(isNull: 1, value: dpiDataBuffer())
                guard dpiStmt_bindValueByPos(handle, i, dpiNativeTypeNum(DPI_NATIVE_TYPE_NULL), &data) == DPI_SUCCESS else {
                    throw OracleError.getLast(for: connection)
                }
            }
        }
    }

    internal func columns() throws -> OracleColumnOffsets {
        var columns: [(String, Int)] = []

        var count: UInt32 = 0
        dpiStmt_getNumQueryColumns(handle, &count)
        connection.logger.debug("Total amount of columns: \(count)")

        // iterate over column count and initialize columns once
        // we will then re-use the columns for each row
        for i in 0..<count {
            try columns.append((self.column(at: Int32(i + 1)), numericCast(i)))
        }

        return .init(offsets: columns)
    }

    internal func nextRow(for columns: OracleColumnOffsets) throws -> OracleRow? {
        // step over the query, this will continue to return ORACLE_ROW
        // for as long as there are new rows to be fetched
        var found: Int32 = 0
        var bufferRowIndex: UInt32 = 0
        dpiStmt_fetch(handle, &found, &bufferRowIndex)

        if found == 0 {
            dpiStmt_release(handle)
            return nil
        }

        var count: UInt32 = 0
        dpiStmt_getNumQueryColumns(handle, &count)
        var row: [OracleData] = []
        for i in 0..<count {
            try row.append(data(at: Int32(i + 1)))
        }
        return OracleRow(columnOffsets: columns, data: row)
    }

    // MARK: - Private

    private func data(at offset: Int32) throws -> OracleData {
        var nativeType = dpiNativeTypeNum()
        var value: UnsafeMutablePointer<dpiData>?
        guard dpiStmt_getQueryValue(handle, UInt32(offset), &nativeType, &value) == DPI_SUCCESS else {
            throw OracleError.getLast(for: connection)
        }
        guard let value else {
            throw OracleError.getLast(for: connection)
        }
        let type = try dataType(for: nativeType)
        switch type {
        case .integer:
            let val = value.pointee.value.asInt64
            let integer = Int(val)
            return .integer(integer)
        case .double:
            let double = value.pointee.value.asDouble
            return .float(double)
        case .text:
            guard let val = value.pointee.value.asString else {
                throw OracleError(reason: .error, message: "Unexpected nil column text")
            }
            let string = String(cString: val)
            return .text(string)
        case .blob:
            let length = Int(value.pointee.value.asBytes.length)
            var buffer = ByteBufferAllocator().buffer(capacity: length)
            if let blobPointer = value.pointee.value.asRaw {
                buffer.writeBytes(UnsafeRawBufferPointer(start: blobPointer.assumingMemoryBound(to: UInt8.self), count: length))
            }
            return .blob(buffer)
        case .null: return .null
        }
    }

    private func dataType(for nativeType: dpiNativeTypeNum) throws -> OracleDataType {
        switch nativeType {
        case UInt32(DPI_NATIVE_TYPE_INT64): return .integer
        case UInt32(DPI_NATIVE_TYPE_DOUBLE): return .double
        case UInt32(DPI_NATIVE_TYPE_BYTES): return .text
        case UInt32(DPI_NATIVE_TYPE_LOB): return .blob
        case UInt32(DPI_NATIVE_TYPE_NULL): return .null
        default: throw OracleError(reason: .error, message: "Unexpected column type: \(nativeType.description)")
        }
    }

    private func column(at offset: Int32) throws -> String {
        var queryInfo = dpiQueryInfo()
        dpiStmt_getQueryInfo(handle, UInt32(offset), &queryInfo)
        return String(cString: queryInfo.name)
    }
}
