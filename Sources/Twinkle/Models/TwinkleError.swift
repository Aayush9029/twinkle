import Foundation

public enum TwinkleError: Error, Equatable, Sendable, LocalizedError {
    case invalidBundle
    case codeSigningMismatch
    case versionMismatch(expected: String, actual: String?)
    case downloadFailed(String)
    case downloadCancelled
    case unzipFailed(String)
    case networkError(URLError.Code)
    case diskSpaceLow(required: Int64, available: Int64)
    case rateLimited(retryAfter: Int?)
    case installationFailed(String)
    case multipleAppsFound(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidBundle:
            "Invalid bundle"
        case .codeSigningMismatch:
            "Code signing mismatch"
        case .versionMismatch(let expected, let actual):
            "Version mismatch: expected \(expected), got \(actual ?? "unknown")"
        case .downloadFailed(let reason):
            "Download failed: \(reason)"
        case .downloadCancelled:
            "Download cancelled"
        case .unzipFailed(let reason):
            "Unzip failed: \(reason)"
        case .networkError(let code):
            "Network error: \(code.rawValue)"
        case .diskSpaceLow(let required, let available):
            "Insufficient disk space: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)) required, \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) available"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                "Rate limited. Try again in \(seconds) seconds"
            } else {
                "Rate limited. Please try again later"
            }
        case .installationFailed(let reason):
            "Installation failed: \(reason)"
        case .multipleAppsFound(let count):
            "Found \(count) apps in archive, expected 1"
        }
    }
}
