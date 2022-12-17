import Foundation

public protocol OracleDataConvertible {
    init?(oracleData: OracleData)
    var oracleData: OracleData? { get }
}

extension String: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard case .text(let value) = oracleData else {
            return nil
        }
        self = value
    }

    public var oracleData: OracleData? { .text(self) }
}

extension FixedWidthInteger {
    public init?(oracleData: OracleData) {
        guard case .integer(let value) = oracleData else {
            return nil
        }
        self = numericCast(value)
    }

    public var oracleData: OracleData? { .integer(numericCast(self)) }
}

extension Int: OracleDataConvertible {}
extension Int8: OracleDataConvertible {}
extension Int16: OracleDataConvertible {}
extension Int32: OracleDataConvertible {}
extension Int64: OracleDataConvertible {}
extension UInt: OracleDataConvertible {}
extension UInt8: OracleDataConvertible {}
extension UInt16: OracleDataConvertible {}
extension UInt32: OracleDataConvertible {}
extension UInt64: OracleDataConvertible {}

extension Double: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard case .double(let value) = oracleData else {
            return nil
        }
        self = value
    }

    public var oracleData: OracleData? { .double(self) }
}

extension Float: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard case .float(let value) = oracleData else {
            return nil
        }
        self = value
    }

    public var oracleData: OracleData? { .float(self) }
}

extension Date: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard case .timestamp(let value) = oracleData else {
            return nil
        }
        self = value
    }

    public var oracleData: OracleData? { .timestamp(self) }
}

extension ByteBuffer: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard case .blob(let value) = oracleData else {
            return nil
        }
        self = value
    }

    public var oracleData: OracleData? { .blob(self) }
}

extension Data: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard case .blob(var value) = oracleData else {
            return nil
        }
        guard let data = value.readBytes(length: value.readableBytes) else {
            return nil
        }
        self = Data(data)
    }

    public var oracleData: OracleData? {
        var buffer = ByteBufferAllocator().buffer(capacity: count)
        buffer.writeBytes(self)
        return .blob(buffer)
    }
}

extension Bool: OracleDataConvertible {
    public init?(oracleData: OracleData) {
        guard let bool = oracleData.bool else {
            return nil
        }
        self = bool
    }

    public var oracleData: OracleData? { .integer(self ? 1 : 0) }
}
