import Foundation
import Twinkle

enum TwinkleDemoStateSample: String, CaseIterable, Identifiable {
    case idle
    case checking
    case upToDate
    case available
    case downloading
    case ready
    case installing
    case failed

    var id: Self { self }

    var state: UpdateState {
        switch self {
        case .idle:
            .idle
        case .checking:
            .checking
        case .upToDate:
            .upToDate
        case .available:
            .available(.preview)
        case .downloading:
            .downloading(.previewBeta, progress: 0.42)
        case .ready:
            .ready(.preview, bundle: URL(fileURLWithPath: "/Applications/Twinkle Demo.app"))
        case .installing:
            .installing
        case .failed:
            .failed(.rateLimited(retryAfter: 60))
        }
    }

    var title: String {
        switch self {
        case .idle:
            "Idle"
        case .checking:
            "Checking"
        case .upToDate:
            "Up to Date"
        case .available:
            "Available"
        case .downloading:
            "Downloading"
        case .ready:
            "Ready"
        case .installing:
            "Installing"
        case .failed:
            "Failed"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            "sparkle"
        case .checking:
            "arrow.triangle.2.circlepath"
        case .upToDate:
            "checkmark.seal"
        case .available:
            "arrow.down.circle"
        case .downloading:
            "icloud.and.arrow.down"
        case .ready:
            "shippingbox"
        case .installing:
            "square.and.arrow.down"
        case .failed:
            "exclamationmark.triangle"
        }
    }
}
