import Testing
import Foundation
@testable import Twinkle

@Suite("Release Tests")
struct ReleaseTests {

    @Test("Decodes GitHub release and converts to Release")
    func decodeGitHubRelease() throws {
        let json = """
        {
            "tag_name": "v2.0.0",
            "name": "Version 2.0.0",
            "body": "### What's New\\n- Feature improvements",
            "prerelease": false,
            "published_at": "2024-01-15T12:00:00Z",
            "assets": [
                {
                    "name": "MyApp.zip",
                    "browser_download_url": "https://example.com/app.zip"
                }
            ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let githubRelease = try decoder.decode(GitHubRelease.self, from: json.data(using: .utf8)!)
        let release = githubRelease.toRelease()

        #expect(release != nil)
        #expect(release?.buildNumber == 20000) // 2*10000 + 0*100 + 0
        #expect(release?.version == "2.0.0")
        #expect(release?.prerelease == false)
        #expect(release?.changelog == "### What's New\n- Feature improvements")
    }

    @Test("Decodes prerelease from GitHub JSON")
    func decodePrerelease() throws {
        let json = """
        {
            "tag_name": "v2.1.0-beta",
            "name": "Beta",
            "body": "",
            "prerelease": true,
            "published_at": null,
            "assets": [{"name": "app.zip", "browser_download_url": "https://a.com/b.zip"}]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let githubRelease = try decoder.decode(GitHubRelease.self, from: json.data(using: .utf8)!)
        let release = githubRelease.toRelease()!

        #expect(release.prerelease == true)
        #expect(release.kind == .prerelease(URL(string: "https://a.com/b.zip")!))
        #expect(release.buildNumber == 20100) // 2.1.0-beta → 2*10000 + 1*100 + 0
    }

    @Test("Version parsing strips leading v")
    func versionParsing() throws {
        let json = """
        {"tag_name": "v3.2.1", "prerelease": false, "assets": [{"name": "a.zip", "browser_download_url": "https://x.com/a.zip"}]}
        """
        let githubRelease = try JSONDecoder().decode(GitHubRelease.self, from: json.data(using: .utf8)!)
        let release = githubRelease.toRelease()!

        #expect(release.version == "3.2.1")
        #expect(release.buildNumber == 30201)
    }

    @Test("Build number computed from semver")
    func buildNumberComputation() throws {
        let testCases: [(String, Int)] = [
            ("v2.1.3", 20103),
            ("v2.0", 20000),
            ("v2", 20000),
            ("2.1.3-beta", 20103),
            ("v0.1.5", 105),
            ("v10.20.30", 102030),
        ]

        for (tag, expectedBuild) in testCases {
            let json = """
            {"tag_name": "\(tag)", "prerelease": false, "assets": [{"name": "a.zip", "browser_download_url": "https://x.com/a.zip"}]}
            """
            let githubRelease = try JSONDecoder().decode(GitHubRelease.self, from: json.data(using: .utf8)!)
            let release = githubRelease.toRelease()!
            #expect(release.buildNumber == expectedBuild, "Tag \(tag) should produce build \(expectedBuild)")
        }
    }

    @Test("Returns nil when no zip asset")
    func noZipAsset() throws {
        let json = """
        {"tag_name": "v1.0.0", "prerelease": false, "assets": [{"name": "source.tar.gz", "browser_download_url": "https://x.com/a.tar.gz"}]}
        """
        let githubRelease = try JSONDecoder().decode(GitHubRelease.self, from: json.data(using: .utf8)!)
        #expect(githubRelease.toRelease() == nil)
    }

    @Test("Extracts banner image from markdown body")
    func extractsBannerImage() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "body": "# Release\\n![Banner](https://example.com/banner.png)\\nMore text",
            "prerelease": false,
            "assets": [{"name": "a.zip", "browser_download_url": "https://x.com/a.zip"}]
        }
        """
        let githubRelease = try JSONDecoder().decode(GitHubRelease.self, from: json.data(using: .utf8)!)
        let release = githubRelease.toRelease()!
        #expect(release.bannerImageUrl == URL(string: "https://example.com/banner.png"))
    }

    @Test("Encodes and decodes round-trip")
    func roundTrip() throws {
        let original = Release.preview
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Release.self, from: data)

        #expect(decoded == original)
    }

    @Test("ID is version string")
    func idIsVersion() {
        #expect(Release.preview.id == "2.0.0")
    }

    @Test("Compared by build number")
    func comparison() {
        #expect(Release.preview2 < Release.preview) // 99 < 100
        #expect(Release.preview < Release.previewBeta) // 100 < 101
        #expect([Release.preview2, Release.previewBeta, Release.preview].max() == Release.previewBeta)
    }

    @Test("Non-semver tags compared by date")
    func nonSemverComparison() {
        let older = Release(
            buildNumber: 0,
            version: "loginflow",
            changelog: "",
            zipUrl: URL(string: "https://x.com/a.zip")!,
            prerelease: false,
            publishedAt: Date(timeIntervalSince1970: 1000)
        )
        let newer = Release(
            buildNumber: 0,
            version: "hotfix",
            changelog: "",
            zipUrl: URL(string: "https://x.com/b.zip")!,
            prerelease: false,
            publishedAt: Date(timeIntervalSince1970: 2000)
        )
        #expect(older < newer)
        #expect([older, newer].max() == newer)
    }

    @Test("Kind returns correct URL")
    func kind() {
        #expect(Release.preview.kind.url == Release.preview.zipUrl)
        #expect(Release.previewBeta.kind == .prerelease(Release.previewBeta.zipUrl))
    }

    @Test("Preview values are valid")
    func previews() {
        #expect(Release.preview.buildNumber == 100)
        #expect(Release.preview2.buildNumber == 99)
        #expect(Release.previewBeta.buildNumber == 101)
    }
}
