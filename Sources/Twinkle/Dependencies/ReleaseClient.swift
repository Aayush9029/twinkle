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
    case downloading(fractionCompleted: Double)
    case completed(savedTo: URL)
}

extension DependencyValues {
    public var releaseClient: ReleaseClient {
        get { self[ReleaseClient.self] }
        set { self[ReleaseClient.self] = newValue }
    }
}
