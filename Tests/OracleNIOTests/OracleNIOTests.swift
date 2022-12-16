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

    var threadPool: NIOThreadPool!
    var eventLoopGroup: EventLoopGroup!
    var eventLoop: EventLoop { self.eventLoopGroup.any() }

    override func setUpWithError() throws {
        threadPool = .init(numberOfThreads: 1)
        threadPool.start()
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        XCTAssert(isLoggingConfigured)
    }

    func testBasicConnection() throws {
        let connection = try OracleConnection.connect(username: Self.username,
                                                      password: Self.password,
                                                      connectionString: Self.connectionString,
                                                      threadPool: threadPool,
                                                      on: eventLoop).wait()
        defer {
            try! connection.close().wait()
        }

        let rows = try connection.query("SELECT 'Hello, World!' FROM dual").wait()
        print(rows)
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
