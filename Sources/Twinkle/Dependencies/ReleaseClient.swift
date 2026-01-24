import Foundation
import Dependencies
import DependenciesMacros
import IdentifiedCollections

@DependencyClient
public struct ReleaseClient: Sendable {
    public var fetchReleases: @Sendable (
        _ owner: String,
        _ repo: String
    ) async throws -> IdentifiedArrayOf<Release>

    public var downloadZip: @Sendable (
        _ url: URL,
        _ destination: URL
    ) -> AsyncThrowingStream<DownloadProgress, Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }
}

public enum DownloadProgress: Sendable, Equatable {
    case downloading(fractionCompleted: Double, bytesReceived: Int64, totalBytes: Int64)
    case completed(savedTo: URL)

    /// Convenience for simple fraction access
    public var fractionCompleted: Double {
        switch self {
        case .downloading(let fraction, _, _): fraction
        case .completed: 1.0
        }
    }
}

extension DependencyValues {
    public var releaseClient: ReleaseClient {
        get { self[ReleaseClient.self] }
        set { self[ReleaseClient.self] = newValue }
    }
}
