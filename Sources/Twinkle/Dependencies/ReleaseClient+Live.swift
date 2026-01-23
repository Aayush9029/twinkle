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

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
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
                let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                    if let error = error {
                        continuation.finish(throwing: error)
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
                    continuation.yield(.downloading(fractionCompleted: progress.fractionCompleted))
                }

                continuation.onTermination = { _ in
                    observation.invalidate()
                    task.cancel()
                }

                task.resume()
            }
        }
    )

    public static let previewValue = ReleaseClient(
        fetchReleases: { _, _ in
            IdentifiedArray(uniqueElements: [.preview, .preview2, .previewBeta])
        },
        downloadZip: { _, destination in
            AsyncThrowingStream { continuation in
                Task {
                    for i in 1...10 {
                        try await Task.sleep(for: .milliseconds(100))
                        continuation.yield(.downloading(fractionCompleted: Double(i) / 10.0))
                    }
                    continuation.yield(.completed(savedTo: destination))
                    continuation.finish()
                }
            }
        }
    )
}
