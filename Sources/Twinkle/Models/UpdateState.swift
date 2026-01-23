import Foundation

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case upToDate
    case available(Release)
    case downloading(Release, progress: Double)
    case ready(Release, bundle: URL)
    case installing
    case failed(TwinkleError)

    public var release: Release? {
        switch self {
        case .available(let r), .downloading(let r, _), .ready(let r, _): r
        default: nil
        }
    }

    public var isChecking: Bool { self == .checking }
}
