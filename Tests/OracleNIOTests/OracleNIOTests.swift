import XCTest
@testable import OracleNIO
import Logging

final class OracleNIOTests: XCTestCase {
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
        let connection = try OracleConnection.open(username: "my_user", password: "my_passwor", connectionString: "//whitewolf.witchers.tech:1521/XEPDB1", clientLibraryDir: nil, threadPool: threadPool, on: eventLoop).wait()
        defer {
            print("closing")
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

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
