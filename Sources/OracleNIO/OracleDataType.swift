/// Supported SQLite column data types when defining schemas.
public enum OracleDataType {
    /// `INTEGER`.
    case integer

    /// `FLOAT`.
    case float

    /// `DOUBLE`.
    case double

    /// `TEXT`.
    case text

    /// `TIMESTAMP`
    case timestamp

    /// `BLOB`.
    case blob

    /// `RAW`.
    case raw

    /// `NULL`.
    case null

    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch self {
        case .integer: return "NUMBER"
        case .float: return "FLOAT"
        case .double: return "DOUBLE"
        case .text: return "VARCHAR(4000)"
        case .raw: return "RAW"
        case .timestamp: return "TIMESTAMP"
        case .blob: return "BLOB"
        case .null: return "NULL"
        }
    }
}
