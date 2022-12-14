import Foundation
import ODPIC

public struct OracleError: Error, CustomStringConvertible, LocalizedError {
    public let reason: Reason
    public let message: String

    public var description: String { "\(reason): \(message)" }

    public var errorDescription: String? { description }

    internal init(reason: Reason, message: String) {
        self.reason = reason
        self.message = message
    }

    internal init(errorInfo: dpiErrorInfo) {
        self.reason = .init(errorInfo: errorInfo)
        self.message = String(cString: errorInfo.message)
    }

    internal init(errorInfo: dpiErrorInfo, connection: OracleConnection) {
        self.reason = .init(errorInfo: errorInfo)
        self.message = connection.errorMessage ?? "Unknown"
    }

    public enum Reason {
        case cantOpen
        case noHandle
        case noContext

        case error
        
        case oracleError(code: Int32)

        internal init(errorInfo: dpiErrorInfo) {
            self = .oracleError(code: errorInfo.code)
        }
    }

    internal static func getLast(for connection: OracleConnection) -> Self {
        guard let context = connection.context else {
            return OracleError(reason: .noContext, message: "The db context is not available, the connection is most likely already closed")
        }

        var errorInfo = dpiErrorInfo()
        dpiContext_getError(context, &errorInfo)
        return OracleError(errorInfo: errorInfo)
    }
}
