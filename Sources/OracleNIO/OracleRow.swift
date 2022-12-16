public struct OracleColumn: CustomStringConvertible {
    public let name: String
    public let data: OracleData

    public var description: String {
        "\(name): \(data)"
    }
}

public struct OracleRow {
    let columnOffsets: OracleColumnOffsets
    let data: [OracleData]

    public var columns: [OracleColumn] {
        columnOffsets.offsets.map { (name, offset) in
            OracleColumn(name: name, data: data[offset])
        }
    }

    public func column(_ name: String) -> OracleData? {
        guard let offset = columnOffsets.lookupTable[name.uppercased()] else {
            return nil
        }
        return data[offset]
    }
}

extension OracleRow: CustomStringConvertible {
    public var description: String {
        columns.description
    }
}

final class OracleColumnOffsets {
    let offsets: [(String, Int)]
    let lookupTable: [String: Int]

    init(offsets: [(String, Int)]) {
        self.offsets = offsets
        self.lookupTable = .init(offsets, uniquingKeysWith: { a, b in a })
    }
}
