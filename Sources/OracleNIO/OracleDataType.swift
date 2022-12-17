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

    /// `BLOB`.
    case blob

    /// `NULL`.
    case null

    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch self {
        case .integer: return "INTEGER"
        case .float: return "FLOAT"
        case .double: return "DOUBLE"
        case .text: return "TEXT"
        case .blob: return "BLOB"
        case .null: return "NULL"
        }
    }
}
