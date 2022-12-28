import struct Foundation.Date

/// Supported Oracle data types
public enum OracleData: Hashable, Equatable, Encodable, CustomStringConvertible {
    /// `Int`.
    case integer(Int)

    /// `Float`.
    case float(Float)

    /// `Double`.
    case double(Double)

    /// `String`.
    case text(String)

    /// `Date`.
    case timestamp(Date)

    /// `ByteBuffer`.
    case blob(ByteBuffer)

    /// `RAW`.
    case raw(ByteBuffer)

    /// `NULL`.
    case null

    public var integer: Int? {
        switch self {
        case .integer(let integer):
            return integer
        case .float(let float):
            return Int(float)
        case .double(let double):
            return Int(double)
        case .text(let string):
            return Int(string)
        case .raw(var buffer):
            guard let bytes = buffer.readBytes(length: MemoryLayout<Int>.size) else {
                return nil
            }
            var int: Int = 0
            withUnsafeMutableBytes(of: &int) { buffer in
                buffer.copyBytes(from: bytes)
            }
            return int
        case .timestamp, .blob, .null:
            return nil
        }
    }

    public var float: Float? {
        switch self {
        case .integer(let integer):
            return Float(integer)
        case .float(let float):
            return float
        case .double(let double):
            return Float(double)
        case .text(let string):
            return Float(string)
        case .raw(var buffer):
            guard let bytes = buffer.readBytes(length: MemoryLayout<Float>.size) else {
                return nil
            }
            var float: Float = 0.0
            withUnsafeMutableBytes(of: &float) { buffer in
                buffer.copyBytes(from: bytes)
            }
            return float
        case .timestamp, .blob, .null:
            return nil
        }
    }

    public var double: Double? {
        switch self {
        case .integer(let integer):
            return Double(integer)
        case .float(let float):
            return Double(float)
        case .double(let double):
            return double
        case .text(let string):
            return Double(string)
        case .raw(var buffer):
            guard let bytes = buffer.readBytes(length: MemoryLayout<Double>.size) else {
                return nil
            }
            var double: Double = 0.0
            withUnsafeMutableBytes(of: &double) { buffer in
                buffer.copyBytes(from: bytes)
            }
            return double
        case .timestamp, .blob, .null:
            return nil
        }
    }

    public var string: String? {
        switch self {
        case .integer(let integer):
            return String(integer)
        case .float(let float):
            return String(float)
        case .double(let double):
            return String(double)
        case .text(let string):
            return string
        case .raw(var buffer):
            return buffer.readString(length: buffer.readableBytes)
        case .timestamp, .blob, .null:
            return nil
        }
    }

    public var bool: Bool? {
        switch self.integer {
        case 0: return false
        case 1, -1: return true
        default: return nil
        }
    }

    public var date: Date? {
        switch self {
        case .timestamp(let date):
            return date
        default: return nil
        }
    }

    /// Description of data.
    public var description: String {
        switch self {
        case .blob(let data): return "<\(data.readableBytes) bytes>"
        case .float(let float): return float.description
        case .double(let double): return double.description
        case .integer(let int): return int.description
        case .timestamp(let date): return date.description
        case .null: return "null"
        case .text(let text): return "\"" + text + "\""
        case .raw(let buffer): return "<\(buffer.readableBytes) bytes>"
        }
    }

    /// See `Encodable`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value): try container.encode(value)
        case .float(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .text(let value): try container.encode(value)
        case .timestamp(let value): try container.encode(value)
        case .blob(var value):
            let bytes = value.readBytes(length: value.readableBytes) ?? []
            try container.encode(bytes)
        case .null: try container.encodeNil()
        case .raw(var value):
            let bytes = value.readBytes(length: value.readableBytes) ?? []
            try container.encode(bytes)
        }
    }
}
