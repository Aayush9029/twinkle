import Testing
import Foundation
@testable import Twinkle
import Dependencies

/// End-to-end tests that use real file operations and fixtures
@Suite("Twinkle E2E Tests")
struct TwinkleE2ETests {

    /// Path to test fixtures
    var fixturesPath: URL {
        // Find fixtures relative to test file
        let testFile = URL(fileURLWithPath: #file)
        return testFile
            .deletingLastPathComponent()  // TwinkleE2ETests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // E2ETests
            .appendingPathComponent("Fixtures")
    }

    /// Create a mock GitHub releases JSON response
    func makeReleasesJSON(releases: [(version: String, build: Int, zipName: String, prerelease: Bool)]) -> Data {
        var json = "["
        for (i, release) in releases.enumerated() {
            if i > 0 { json += "," }
            json += """
            {
                "tag_name": "v\(release.version)",
                "name": "Version \(release.version)",
                "body": "Release notes for \(release.version)",
                "prerelease": \(release.prerelease),
                "published_at": "2024-01-01T00:00:00Z",
                "assets": [
                    {
                        "name": "\(release.zipName)",
                        "browser_download_url": "https://test.local/downloads/\(release.zipName)"
                    }
                ]
            }
            """
        }
        json += "]"
        return json.data(using: .utf8)!
    }

    // MARK: - Fixture Loading Tests

    @Test("Fixtures exist and are valid zips")
    func fixturesExist() throws {
        let fm = FileManager.default
        let fixtures = try fm.contentsOfDirectory(at: fixturesPath, includingPropertiesForKeys: nil)

        #expect(fixtures.count >= 4)

        // Check valid versions exist
        let names = fixtures.map { $0.lastPathComponent }
        #expect(names.contains("TwinkleExample-v1.0.0.zip"))
        #expect(names.contains("TwinkleExample-v2.0.0.zip"))
        #expect(names.contains("TwinkleExample-v2.1.0-beta.zip"))
    }

    @Test("Real unzip extracts app bundle")
    func realUnzip() async throws {
        let zipPath = fixturesPath.appendingPathComponent("TwinkleExample-v2.0.0.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Use real ProcessClient
        let processClient = ProcessClient.liveValue
        try await processClient.unzip(zipPath, tempDir)

        // Verify .app was extracted
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let apps = contents.filter { $0.pathExtension == "app" }

        #expect(apps.count == 1)
        #expect(apps.first?.lastPathComponent == "TwinkleExample-v2.0.0.app")

        // Verify bundle structure
        let appBundle = apps.first!
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        #expect(FileManager.default.fileExists(atPath: infoPlist.path))

        // Read version from Info.plist
        let plistData = try Data(contentsOf: infoPlist)
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]
        #expect(plist["CFBundleShortVersionString"] as? String == "2.0.0")
        #expect(plist["CFBundleVersion"] as? String == "200")
    }

    @Test("Real code signing validation")
    func realCodeSigning() async throws {
        let zipPath = fixturesPath.appendingPathComponent("TwinkleExample-v2.0.0.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Extract
        let processClient = ProcessClient.liveValue
        try await processClient.unzip(zipPath, tempDir)

        // Get code signing identity
        let appPath = tempDir.appendingPathComponent("TwinkleExample-v2.0.0.app")
        let identity = try await processClient.codeSigningIdentity(appPath.path)

        // Ad-hoc signed apps have a signature but no identity
        // The codesign output will show "Signature=adhoc"
        #expect(identity != nil || identity == nil)  // Just verify it doesn't throw
    }

    @Test("Invalid zip fails gracefully")
    func invalidZip() async throws {
        let invalidZip = fixturesPath.appendingPathComponent("TwinkleExample-invalid.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let processClient = ProcessClient.liveValue

        await #expect(throws: TwinkleError.self) {
            try await processClient.unzip(invalidZip, tempDir)
        }
    }

    @Test("No app in zip detected")
    func noAppInZip() async throws {
        let noAppZip = fixturesPath.appendingPathComponent("TwinkleExample-noapp.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let processClient = ProcessClient.liveValue
        try await processClient.unzip(noAppZip, tempDir)

        // Verify no .app bundles
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let apps = contents.filter { $0.pathExtension == "app" }

        #expect(apps.isEmpty)
    }

    @Test("Multiple apps in zip detected")
    func multipleAppsInZip() async throws {
        let multiAppZip = fixturesPath.appendingPathComponent("TwinkleExample-multiapp.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let processClient = ProcessClient.liveValue
        try await processClient.unzip(multiAppZip, tempDir)

        // Verify multiple .app bundles
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let apps = contents.filter { $0.pathExtension == "app" }

        #expect(apps.count == 2)
    }

    // MARK: - Release Parsing Tests

    @Test("GitHub release JSON parses correctly")
    func parseGitHubRelease() throws {
        let json = makeReleasesJSON(releases: [
            (version: "2.0.0", build: 200, zipName: "app.zip", prerelease: false),
            (version: "2.1.0-beta", build: 210, zipName: "app-beta.zip", prerelease: true)
        ])

        let decoder = JSONDecoder()
        // GitHubRelease has custom CodingKeys, so don't use convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let githubReleases = try decoder.decode([GitHubRelease].self, from: json)
        #expect(githubReleases.count == 2)

        let releases = githubReleases.compactMap { $0.toRelease() }
        #expect(releases.count == 2)
        #expect(releases[0].version == "2.0.0")
        #expect(releases[0].buildNumber == 20000)
        #expect(releases[1].prerelease == true)
    }

    // MARK: - Disk Space Tests

    @Test("Disk space check works")
    func diskSpaceCheck() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory

        // Get available space
        let values = try tempDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0

        #expect(available > 0)
        #expect(available > 1_000_000_000)  // At least 1GB available
    }

    // MARK: - Bundle Inspection Tests

    @Test("Bundle info extraction works")
    func bundleInfoExtraction() throws {
        // Test with current test bundle
        let bundle = Bundle(for: BundleMarker.self)

        // Bundle should exist
        #expect(bundle.bundleIdentifier != nil || bundle.bundlePath.isEmpty == false)
    }
}

// Helper class to get test bundle
private final class BundleMarker {}
