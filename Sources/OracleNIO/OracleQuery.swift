/// A Oracle SQL query, that can be executed on a Oracle connection. Contains the raw sql string and bindings.
public struct OracleQuery: Hashable {
    /// The query string.
    public var sql: String

    /// The query binds.
    public var binds: OracleBindings

    public init(unsafeSQL sql: String, binds: OracleBindings = OracleBindings()) {
        self.sql = sql
        self.binds = binds
    }
}

extension OracleQuery: ExpressibleByStringInterpolation {
    public init(stringInterpolation: StringInterpolation) {
        self.sql = stringInterpolation.sql
        self.binds = stringInterpolation.binds
    }

    public init(stringLiteral value: String) {
        self.sql = value
        self.binds = OracleBindings()
    }
}

extension OracleQuery {
    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        @usableFromInline
        var sql: String
        @usableFromInline
        var binds: OracleBindings

        public init(literalCapacity: Int, interpolationCount: Int) {
            sql = ""
            binds = OracleBindings()
        }

        public mutating func appendLiteral(_ literal: String) {
            sql.append(contentsOf: literal)
        }

        @inlinable
        public mutating func appendInterpolation<Value: OracleDataConvertible>(_ value: Value) throws {
            try binds.append(value)
            sql.append(contentsOf: ":\(binds.count)")
        }

        @inlinable
        public mutating func appendInterpolation<Value: OracleDataConvertible>(_ value: Optional<Value>) throws {
            switch value {
            case .none:
                binds.appendNull()
            case .some(let value):
                try binds.append(value)
            }

            sql.append(contentsOf: ":\(self.binds.count)")
        }

        @inlinable
        public mutating func appendInterpolation(unescaped interpolated: String) {
            sql.append(contentsOf: interpolated)
        }
    }
}

public struct OracleBindings: Hashable {
    @usableFromInline
    var values: [OracleData]

    public var count: Int {
        values.count
    }

    public init() {
        values = []
    }

    @inlinable
    mutating func appendNull() {
        values.append(.null)
    }

    @inlinable
    mutating func append<Value: OracleDataConvertible>(_ value: Value) throws {
        guard let oracleData = value.oracleData else {
            throw OracleError(reason: .error, message: "Provided value does not contain any associated oracle data")
        }
        values.append(oracleData)
    }
}
