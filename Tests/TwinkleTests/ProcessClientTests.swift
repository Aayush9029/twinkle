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

    // MARK: - Real Process Tests

    @Test("Live unzip extracts real zip file")
    func liveUnzip() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let zipPath = tempDir.appendingPathComponent("test.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a simple zip file using the zip command
        let testFile = tempDir.appendingPathComponent("hello.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.arguments = ["-j", zipPath.path, testFile.path]
        zipProcess.currentDirectoryURL = tempDir
        try zipProcess.run()
        zipProcess.waitUntilExit()

        // Use live unzip
        let client = ProcessClient.liveValue
        try await client.unzip(zipPath, extractDir)

        // Verify extraction
        let extractedFile = extractDir.appendingPathComponent("hello.txt")
        #expect(FileManager.default.fileExists(atPath: extractedFile.path))

        let content = try String(contentsOf: extractedFile, encoding: .utf8)
        #expect(content == "Hello, World!")
    }

    @Test("Live unzip fails on invalid zip")
    func liveUnzipInvalidZip() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let invalidZip = tempDir.appendingPathComponent("invalid.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create invalid zip file
        try "not a zip file".write(to: invalidZip, atomically: true, encoding: .utf8)

        let client = ProcessClient.liveValue

        await #expect(throws: TwinkleError.self) {
            try await client.unzip(invalidZip, extractDir)
        }
    }

    @Test("Live codesign reads identity from signed app")
    func liveCodesign() async throws {
        // Use a system app that's always present and signed
        let systemApp = "/System/Applications/Calculator.app"

        guard FileManager.default.fileExists(atPath: systemApp) else {
            // Skip if Calculator doesn't exist (unlikely)
            return
        }

        let client = ProcessClient.liveValue
        let identity = try await client.codeSigningIdentity(systemApp)

        // System apps are signed by Apple
        #expect(identity != nil)
        #expect(identity?.contains("Apple") == true || identity?.contains("Software Signing") == true)
    }
}
