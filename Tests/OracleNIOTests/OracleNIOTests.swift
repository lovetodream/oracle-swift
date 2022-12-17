import XCTest
@testable import OracleNIO
import Logging

final class OracleNIOTests: XCTestCase {
    static let username: String = {
        guard let value = env("ORA_USER") else {
            fatalError(envFailureReason("ORA_USER", is: "oracle username"))
        }
        return value
    }()
    static let password: String = {
        guard let value = env("ORA_PWD") else {
            fatalError(envFailureReason("ORA_PWD", is: "oracle password"))
        }
        return value
    }()
    static let connectionString: String = {
        guard let value = env("ORA_CONN") else {
            fatalError(envFailureReason("ORA_CONN", is: "oracle connection string"))
        }
        return value
    }()
    static let oicLib: String? = {
        env("ORA_OIC")
    }()

    var threadPool: NIOThreadPool!
    var eventLoopGroup: EventLoopGroup!
    var eventLoop: EventLoop { self.eventLoopGroup.any() }

    override func setUpWithError() throws {
        threadPool = .init(numberOfThreads: 1)
        threadPool.start()
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        XCTAssert(isLoggingConfigured)
    }

    override func tearDownWithError() throws {
        try threadPool.syncShutdownGracefully()
        try eventLoopGroup.syncShutdownGracefully()
    }

    func testBasicConnection() throws {
        let connection = try OracleConnection.connect(username: Self.username,
                                                      password: Self.password,
                                                      connectionString: Self.connectionString,
                                                      clientLibraryDir: Self.oicLib,
                                                      threadPool: threadPool,
                                                      on: eventLoop).wait()
        defer { try! connection.close().wait() }

        let rows = try connection.query("SELECT 'Hello, World!' as value FROM dual").wait()
        print(rows)
    }

    func testBindingString() async throws {
        let connection = try await OracleConnection.connect(username: Self.username,
                                                            password: Self.password,
                                                            connectionString: Self.connectionString,
                                                            clientLibraryDir: Self.oicLib,
                                                            threadPool: threadPool,
                                                            on: eventLoop)
        defer { try! connection.close().wait() }

        let value = "Hello, World!"
        let rows = try await connection.query("SELECT \(value) as value FROM dual")
        XCTAssertEqual(value, rows.first?.column("value")?.string)
    }

    func testBindingNumeric() async throws {
        let connection = try await OracleConnection.connect(username: Self.username,
                                                            password: Self.password,
                                                            connectionString: Self.connectionString,
                                                            clientLibraryDir: Self.oicLib,
                                                            threadPool: threadPool,
                                                            on: eventLoop)
        defer { try! connection.close().wait() }

        let value = 1
        let rows = try await connection.query("SELECT \(value) as value FROM dual")
        XCTAssertEqual(value, rows.first?.column("value")?.integer)
    }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = env("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .debug
        return handler
    }
    return true
}()

func envFailureReason(_ envName: String, is usageDescription: String) -> String {
    "Add `\(envName)` (\(usageDescription)) to the environment, it is required to run tests"
}

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
