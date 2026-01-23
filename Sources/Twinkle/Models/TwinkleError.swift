import Foundation

public enum TwinkleError: Error, Equatable, Sendable, LocalizedError {
    case invalidBundle
    case codeSigningMismatch
    case versionMismatch(expected: String, actual: String?)
    case downloadFailed(String)
    case unzipFailed(String)
    case networkError(URLError.Code)

    public var errorDescription: String? {
        switch self {
        case .invalidBundle: "Invalid bundle"
        case .codeSigningMismatch: "Code signing mismatch"
        case .versionMismatch(let expected, let actual):
            "Version mismatch: expected \(expected), got \(actual ?? "unknown")"
        case .downloadFailed(let reason): "Download failed: \(reason)"
        case .unzipFailed(let reason): "Unzip failed: \(reason)"
        case .networkError(let code): "Network error: \(code.rawValue)"
        }
    }
}
