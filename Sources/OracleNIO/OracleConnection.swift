import ODPIC

public protocol OracleDatabase {
    var logger: Logger { get }
    var eventLoop: EventLoop { get }

    func query(_ query: OracleQuery, logger: Logger, _ onRow: @escaping (OracleRow) throws -> Void) -> EventLoopFuture<Void>

    func withConnection<T>(_ closure: @escaping (OracleConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T>
}

extension OracleDatabase {
    public func query(_ query: OracleQuery, _ onRow: @escaping (OracleRow) throws -> Void) -> EventLoopFuture<Void> {
        self.query(query, logger: logger, onRow)
    }

    public func query(_ query: OracleQuery) -> EventLoopFuture<[OracleRow]> {
        var rows = [OracleRow]()
        return self.query(query, logger: logger) { row in
            rows.append(row)
        }.map { rows }
    }
}

extension OracleDatabase {
    public func logging(to logger: Logger) -> OracleDatabase {
        _OracleDatabaseCustomLogger(database: self, logger: logger)
    }
}

private struct _OracleDatabaseCustomLogger: OracleDatabase {
    let database: OracleDatabase
    var eventLoop: EventLoop {
        self.database.eventLoop
    }
    let logger: Logger

    func withConnection<T>(_ closure: @escaping (OracleConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.database.withConnection(closure)
    }

    func query(_ query: OracleQuery, logger: Logger, _ onRow: @escaping (OracleRow) throws -> Void) -> EventLoopFuture<Void> {
        self.database.query(query, logger: logger, onRow)
    }
}

public final class OracleConnection: OracleDatabase {
    public enum AuthorizationMode {
        case `default`
        case prelim
        case sysASM
        case sysBackup
        case sysDBA
        case sysDGD
        case sysKMT
        case sysOPER
        case sysRAC

        internal var cValue: Int32 {
            switch self {
            case .default:
                return DPI_MODE_AUTH_DEFAULT
            case .prelim:
                return DPI_MODE_AUTH_PRELIM
            case .sysASM:
                return DPI_MODE_AUTH_SYSASM
            case .sysBackup:
                return DPI_MODE_AUTH_SYSBKP
            case .sysDBA:
                return DPI_MODE_AUTH_SYSDBA
            case .sysDGD:
                return DPI_MODE_AUTH_SYSDGD
            case .sysKMT:
                return DPI_MODE_AUTH_SYSKMT
            case .sysOPER:
                return DPI_MODE_AUTH_SYSOPER
            case .sysRAC:
                return DPI_MODE_AUTH_SYSRAC
            }
        }
    }

    /// This enumeration identifies the purity of the sessions that are acquired when using connection classes during connection creation.
    public enum Purity {
        /// Default value used when creating connections.
        case `default`
        /// A connection is required that has not been tainted with any prior session state.
        case new
        /// A connection is permitted to have prior session state.
        case `self`

        internal var cValue: Int32 {
            switch self {
            case .default:
                return DPI_PURITY_DEFAULT
            case .new:
                return DPI_PURITY_NEW
            case .`self`:
                return DPI_PURITY_SELF
            }
        }
    }

    public let eventLoop: EventLoop

    internal var handle: OpaquePointer?
    internal var context: OpaquePointer?
    internal let threadPool: NIOThreadPool
    public let logger: Logger

    public var isClosed: Bool {
        self.handle == nil
    }

    public static func connect(
        authorizationMode: AuthorizationMode = .default,
        username: String,
        password: String,
        connectionString: String,
        clientLibraryDir: String? = nil,
        threadPool: NIOThreadPool,
        logger: Logger = .init(label: "com.timozacherl.oracle"),
        on eventLoop: EventLoop
    ) -> EventLoopFuture<OracleConnection> {
        let promise = eventLoop.makePromise(of: OracleConnection.self)
        var context: OpaquePointer?
        var errorInfo = dpiErrorInfo()
        var cConnection: OpaquePointer? = nil
        let createParams = clientLibraryDir?.withCString { pointer in
            "oracle-nio".withCString {
                return dpiContextCreateParams(defaultDriverName: $0, defaultEncoding: nil, loadErrorUrl: nil, oracleClientLibDir: pointer, oracleClientConfigDir: nil)
            }
        }
        if var createParams, dpiContext_createWithParams(UInt32(DPI_MAJOR_VERSION), UInt32(DPI_MINOR_VERSION), &createParams, &context, &errorInfo) != DPI_SUCCESS {
            logger.error("Failed to create context with parameters")
            promise.fail(OracleError(errorInfo: errorInfo))
        } else if dpiContext_createWithParams(UInt32(DPI_MAJOR_VERSION), UInt32(DPI_MINOR_VERSION), nil, &context, &errorInfo) != DPI_SUCCESS {
            logger.error("Failed to create context")
            promise.fail(OracleError(errorInfo: errorInfo))
        } else if dpiConn_create(context, username, UInt32(username.count), password, UInt32(password.count), connectionString, UInt32(connectionString.count), nil, nil, &cConnection) == DPI_SUCCESS {
            let connection = OracleConnection(handle: cConnection, context: context, threadPool: threadPool, logger: logger, on: eventLoop)
            logger.debug("Connected to oracle db")
            promise.succeed(connection)
        } else {
            logger.error("Failed to connect to db")
            dpiContext_getError(context, &errorInfo)
            promise.fail(OracleError(errorInfo: errorInfo))
        }
        return promise.futureResult
    }

    init(handle: OpaquePointer? = nil,
         context: OpaquePointer? = nil,
         threadPool: NIOThreadPool,
         logger: Logger,
         on eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.handle = handle
        self.context = context
        self.threadPool = threadPool
        self.logger = logger
    }

    public static func libraryMajorVersion() -> Int32 { DPI_MAJOR_VERSION }
    public static func libraryMinorVersion() -> Int32 { DPI_MINOR_VERSION }
    public static func libraryPatchVersion() -> Int32 { DPI_PATCH_LEVEL }

    internal var errorMessage: String? {
        var errorInfo = dpiErrorInfo()
        dpiContext_getError(context, &errorInfo)
        return String(cString: errorInfo.message)
    }

    public func withConnection<T>(_ closure: @escaping (OracleConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        closure(self)
    }

    public func query(_ query: OracleQuery, logger: Logger, _ onRow: @escaping (OracleRow) throws -> Void) -> EventLoopFuture<Void> {
        logger.debug("\(query.sql) \(query.binds.values)")
        let promise = self.eventLoop.makePromise(of: Void.self)
        threadPool.submit { state in
            do {
                let statement = try OracleStatement(query: query.sql, on: self)
                logger.trace("Adding binds...")
                try statement.bind(query.binds.values)
                logger.trace("Binds added successfully")
                logger.trace("Executing statement...")
                try statement.execute()
                logger.trace("Executed statement successfully")
                logger.trace("Fetching columns...")
                let columns = try statement.columns()
                logger.trace("Columns fetched successfully")
                var callbacks: [EventLoopFuture<Void>] = []
                while let row = try statement.nextRow(for: columns) {
                    let callback = self.eventLoop.submit {
                        try onRow(row)
                    }
                    callbacks.append(callback)
                }
                EventLoopFuture<Void>.andAllSucceed(callbacks, on: self.eventLoop).cascade(to: promise)
            } catch {
                logger.error("\(error.localizedDescription)")
                promise.fail(error)
            }
        }
        return promise.futureResult
    }

    public func close() -> EventLoopFuture<Void> {
        let promise = eventLoop.makePromise(of: Void.self)
        self.threadPool.submit { state in
            dpiConn_close(self.handle, dpiConnCloseMode(DPI_MODE_CONN_CLOSE_DEFAULT), "", 0)
            dpiContext_destroy(self.context)
            self.eventLoop.submit {
                self.handle = nil
                self.context = nil
            }.cascade(to: promise)
        }
        return promise.futureResult
    }

    deinit {
        assert(handle == nil && context == nil, "OracleConnection was not closed before deinitializing")
    }
}


// MARK: Async/Await Interface

#if canImport(_Concurrency)
extension OracleConnection {
    public static func connect(
        authorizationMode: AuthorizationMode = .default,
        username: String,
        password: String,
        connectionString: String,
        clientLibraryDir: String? = nil,
        threadPool: NIOThreadPool,
        logger: Logger = .init(label: "com.timozacherl.oracle"),
        on eventLoop: EventLoop
    ) async throws -> OracleConnection {
        try await connect(
            authorizationMode: authorizationMode,
            username: username,
            password: password,
            connectionString: connectionString,
            clientLibraryDir: clientLibraryDir,
            threadPool: threadPool,
            logger: logger,
            on: eventLoop
        ).get()
    }

    public func close() async throws {
        try await self.close().get()
    }

    @discardableResult
    public func query(_ query: OracleQuery) async throws -> [OracleRow] {
        try await self.query(query).get()
    }
}
#endif

// MARK: Alternative Queries

extension OracleConnection {
    public func query(_ string: String, binds: [OracleData] = []) -> EventLoopFuture<[OracleRow]> {
        var rows = [OracleRow]()
        return self.query(string, binds: binds) { row in
            rows.append(row)
        }.map { rows }
    }

    public func query(_ string: String, binds: [OracleData] = [], onRow: @escaping (OracleRow) throws -> ()) -> EventLoopFuture<Void> {
        var bindings = OracleBindings()
        bindings.values = binds
        let query = OracleQuery(unsafeSQL: string, binds: bindings)
        return self.query(query, onRow)
    }

    public func query(_ string: String, binds: [OracleData] = [], logger: Logger, onRow: @escaping (OracleRow) throws -> ()) -> EventLoopFuture<Void> {
        var bindings = OracleBindings()
        bindings.values = binds
        let query = OracleQuery(unsafeSQL: string, binds: bindings)
        return self.query(query, logger: logger, onRow)
    }
}
