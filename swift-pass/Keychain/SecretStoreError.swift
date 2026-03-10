import Foundation
import Security

enum SecretStoreError: LocalizedError {
    case secretNotFound(String)
    case invalidSecretData(String)
    case invalidSecretEncoding(String)
    case operationFailed(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case let .secretNotFound(name):
            return "No secret named '\(name)' was found in the macOS Keychain."
        case let .invalidSecretData(name):
            return "The stored value for '\(name)' could not be read from the macOS Keychain."
        case let .invalidSecretEncoding(name):
            return "The value for '\(name)' could not be encoded for storage."
        case let .operationFailed(operation, status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Could not \(operation) (\(message), OSStatus \(status))."
        }
    }
}
