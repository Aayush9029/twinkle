import Testing
import Foundation
import Dependencies
import IdentifiedCollections
@testable import Twinkle

@Suite("ReleaseClient Tests")
struct ReleaseClientTests {

    @Test("Preview returns mock releases")
    func previewFetchReleases() async throws {
        let releases = try await ReleaseClient.previewValue.fetchReleases("owner", "repo")

        #expect(releases.count == 3)
        #expect(releases[id: "2.0.0"] != nil)
    }

    @Test("Preview download emits progress")
    func previewDownload() async throws {
        var progressCount = 0
        var completed = false

        for try await progress in ReleaseClient.previewValue.downloadZip(
            URL(string: "https://example.com/app.zip")!,
            URL(fileURLWithPath: "/tmp/test.zip")
        ) {
            switch progress {
            case .downloading: progressCount += 1
            case .completed: completed = true
            }
        }

        #expect(progressCount == 10)
        #expect(completed == true)
    }

    @Test("Custom client works")
    func customClient() async throws {
        let client = ReleaseClient(
            fetchReleases: { owner, repo in
                #expect(owner == "test")
                return [Release.preview]
            },
            downloadZip: { _, dest in
                AsyncThrowingStream { c in
                    c.yield(.completed(savedTo: dest))
                    c.finish()
                }
            }
        )

        let releases = try await client.fetchReleases("test", "repo")
        #expect(releases.count == 1)
    }

    @Test("Fetch can throw errors")
    func fetchThrows() async {
        let client = ReleaseClient(
            fetchReleases: { _, _ in throw TwinkleError.networkError(.badServerResponse) },
            downloadZip: { _, _ in AsyncThrowingStream { $0.finish() } }
        )

        await #expect(throws: TwinkleError.self) {
            try await client.fetchReleases("owner", "repo")
        }
    }

    @Test("DownloadProgress equality")
    func downloadProgressEquality() {
        let p1 = DownloadProgress.downloading(fractionCompleted: 0.5, bytesReceived: 500, totalBytes: 1000)
        let p2 = DownloadProgress.downloading(fractionCompleted: 0.5, bytesReceived: 500, totalBytes: 1000)
        let p3 = DownloadProgress.downloading(fractionCompleted: 0.7, bytesReceived: 700, totalBytes: 1000)

        #expect(p1 == p2)
        #expect(p1 != p3)
    }

    @Test("DownloadProgress provides fraction convenience")
    func downloadProgressFraction() {
        let downloading = DownloadProgress.downloading(fractionCompleted: 0.5, bytesReceived: 500, totalBytes: 1000)
        let completed = DownloadProgress.completed(savedTo: URL(fileURLWithPath: "/tmp/test.zip"))

        #expect(downloading.fractionCompleted == 0.5)
        #expect(completed.fractionCompleted == 1.0)
    }
}
