import Foundation
import Dependencies
import DependenciesMacros

/// Client for accessing bundle info
@DependencyClient
public struct BundleInfoClient: Sendable {
    public var bundleIdentifier: @Sendable () -> String? = { nil }
    public var bundleVersion: @Sendable () -> String? = { nil }
    public var shortVersionString: @Sendable () -> String? = { nil }
    public var bundleURL: @Sendable () -> URL = { URL(fileURLWithPath: "/") }
}

extension DependencyValues {
    public var bundleInfo: BundleInfoClient {
        get { self[BundleInfoClient.self] }
        set { self[BundleInfoClient.self] = newValue }
    }
}

extension BundleInfoClient: DependencyKey {
    public static let liveValue = BundleInfoClient(
        bundleIdentifier: { Bundle.main.bundleIdentifier },
        bundleVersion: { Bundle.main.infoDictionary?["CFBundleVersion"] as? String },
        shortVersionString: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String },
        bundleURL: { Bundle.main.bundleURL }
    )

    public static let previewValue = BundleInfoClient(
        bundleIdentifier: { "com.example.preview" },
        bundleVersion: { "99" },
        shortVersionString: { "1.0.0" },
        bundleURL: { URL(fileURLWithPath: "/Applications/Preview.app") }
    )

    public static let testValue = BundleInfoClient()
}
