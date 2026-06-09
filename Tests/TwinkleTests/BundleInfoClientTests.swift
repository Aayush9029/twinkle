import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
@testable import Twinkle

@Suite("BundleInfoClient Tests")
struct BundleInfoClientTests {

    @Test("Preview value returns mock data")
    func previewValue() {
        let client = BundleInfoClient.previewValue

        #expect(client.bundleIdentifier() == "com.example.preview")
        #expect(client.bundleVersion() == "99")
        #expect(client.shortVersionString() == "1.0.0")
    }

    @Test("Custom client works")
    func customClient() {
        let client = BundleInfoClient(
            bundleIdentifier: { "com.test" },
            bundleVersion: { "42" },
            shortVersionString: { "1.2.3" },
            bundleURL: { URL(fileURLWithPath: "/test") }
        )

        #expect(client.bundleIdentifier() == "com.test")
        #expect(client.bundleVersion() == "42")
    }

    @Test("Dependency injection works")
    func dependencyInjection() {
        withDependencies {
            $0.bundleInfo = BundleInfoClient(
                bundleIdentifier: { "injected" },
                bundleVersion: { "999" },
                shortVersionString: { "9.9" },
                bundleURL: { URL(fileURLWithPath: "/") }
            )
        } operation: {
            @Dependency(\.bundleInfo) var bundleInfo
            #expect(bundleInfo.bundleIdentifier() == "injected")
        }
    }
}
