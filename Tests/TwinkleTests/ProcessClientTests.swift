import Testing
import Foundation
import Dependencies
@testable import Twinkle

@Suite("ProcessClient Tests")
struct ProcessClientTests {

    @Test("Preview unzip completes without error")
    func previewUnzip() async throws {
        try await ProcessClient.previewValue.unzip(
            URL(fileURLWithPath: "/fake.zip"),
            URL(fileURLWithPath: "/dest")
        )
    }

    @Test("Preview returns mock code signing identity")
    func previewCodeSigning() async throws {
        let identity = try await ProcessClient.previewValue.codeSigningIdentity("/app")
        #expect(identity?.contains("Mock Developer") == true)
    }

    @Test("Custom client executes closures")
    func customClient() async throws {
        let client = ProcessClient(
            unzip: { _, _ in },
            codeSigningIdentity: { _ in "Custom" }
        )

        try await client.unzip(URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/"))
        let identity = try await client.codeSigningIdentity("/")

        #expect(identity == "Custom")
    }

    @Test("Unzip can throw errors")
    func unzipThrows() async {
        let client = ProcessClient(
            unzip: { _, _ in throw TwinkleError.unzipFailed("test") },
            codeSigningIdentity: { _ in nil }
        )

        await #expect(throws: TwinkleError.self) {
            try await client.unzip(URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/"))
        }
    }
}
