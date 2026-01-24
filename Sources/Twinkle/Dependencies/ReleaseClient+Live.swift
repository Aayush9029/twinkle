import Foundation
import Dependencies
import IdentifiedCollections

extension ReleaseClient: DependencyKey {
    public static let liveValue = ReleaseClient(
        fetchReleases: { owner, repo in
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TwinkleError.networkError(.badServerResponse)
            }

            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Int($0) }
                throw TwinkleError.rateLimited(retryAfter: retryAfter)
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TwinkleError.networkError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let githubReleases = try decoder.decode([GitHubRelease].self, from: data)

            // Convert to Release, filtering out releases without .zip assets
            let releases = githubReleases.compactMap { $0.toRelease() }
            return IdentifiedArray(uniqueElements: releases)
        },

        downloadZip: { url, destination in
            AsyncThrowingStream { continuation in
                // First, make a HEAD request to get content length for disk space check
                var headRequest = URLRequest(url: url)
                headRequest.httpMethod = "HEAD"

                Task {
                    do {
                        let (_, headResponse) = try await URLSession.shared.data(for: headRequest)
                        if let httpResponse = headResponse as? HTTPURLResponse,
                           let contentLengthStr = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                           let contentLength = Int64(contentLengthStr) {

                            // Check available disk space (need ~2x for download + extraction)
                            let requiredSpace = contentLength * 3  // Safety margin for extraction
                            if let availableSpace = try? availableDiskSpace(),
                               availableSpace < requiredSpace {
                                continuation.finish(throwing: TwinkleError.diskSpaceLow(
                                    required: requiredSpace,
                                    available: availableSpace
                                ))
                                return
                            }
                        }
                    } catch {
                        // If HEAD fails, proceed anyway - download will fail if space is truly insufficient
                    }

                    // Proceed with download
                    let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                        if let error = error as? URLError, error.code == .cancelled {
                            continuation.finish(throwing: TwinkleError.downloadCancelled)
                            return
                        }

                        if let error = error {
                            continuation.finish(throwing: TwinkleError.downloadFailed(error.localizedDescription))
                            return
                        }

                        guard let tempURL = tempURL else {
                            continuation.finish(throwing: TwinkleError.downloadFailed("No file received"))
                            return
                        }

                        do {
                            try? FileManager.default.removeItem(at: destination)
                            try FileManager.default.moveItem(at: tempURL, to: destination)
                            continuation.yield(.completed(savedTo: destination))
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }

                    let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                        continuation.yield(.downloading(
                            fractionCompleted: progress.fractionCompleted,
                            bytesReceived: progress.completedUnitCount,
                            totalBytes: progress.totalUnitCount
                        ))
                    }

                    continuation.onTermination = { _ in
                        observation.invalidate()
                        task.cancel()
                    }

                    task.resume()
                }
            }
        }
    )

    private static func availableDiskSpace() throws -> Int64 {
        let fileURL = FileManager.default.temporaryDirectory
        let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    public static let previewValue = ReleaseClient(
        fetchReleases: { _, _ in
            IdentifiedArray(uniqueElements: [.preview, .preview2, .previewBeta])
        },
        downloadZip: { _, destination in
            AsyncThrowingStream { continuation in
                Task {
                    let totalBytes: Int64 = 10_000_000  // 10 MB mock download
                    for i in 1...10 {
                        try await Task.sleep(for: .milliseconds(100))
                        let bytesReceived = Int64(i) * 1_000_000
                        continuation.yield(.downloading(
                            fractionCompleted: Double(i) / 10.0,
                            bytesReceived: bytesReceived,
                            totalBytes: totalBytes
                        ))
                    }
                    continuation.yield(.completed(savedTo: destination))
                    continuation.finish()
                }
            }
        }
    )
}
