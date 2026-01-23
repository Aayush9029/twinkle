import Foundation

/// Represents a release from GitHub's REST API
/// https://docs.github.com/en/rest/releases/releases
struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let name: String?
    let body: String?
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [Asset]

    struct Asset: Codable, Sendable {
        let name: String
        let browserDownloadUrl: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

// MARK: - Conversion to Release

extension GitHubRelease {
    /// Converts a GitHub release to a Twinkle Release
    /// Returns nil if no .zip asset is found
    func toRelease() -> Release? {
        guard let zipAsset = assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            return nil
        }

        let version = parseVersion(from: tagName)
        let buildNumber = computeBuildNumber(from: version)

        return Release(
            buildNumber: buildNumber,
            version: version,
            changelog: body ?? "",
            bannerImageUrl: extractFirstImage(from: body),
            zipUrl: zipAsset.browserDownloadUrl,
            prerelease: prerelease,
            publishedAt: publishedAt
        )
    }

    /// Strips leading "v" from tag name
    /// "v2.0.0" → "2.0.0", "2.0.0" → "2.0.0"
    private func parseVersion(from tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Converts semver to integer: major*10000 + minor*100 + patch
    /// "2.1.3" → 20103, "2.0" → 20000, "2" → 20000
    /// Strips any suffix after hyphen: "2.1.3-beta" → 20103
    private func computeBuildNumber(from version: String) -> Int {
        // Strip any suffix (e.g., "-beta", "-rc1")
        let baseVersion = version.split(separator: "-").first ?? Substring(version)

        let components = baseVersion.split(separator: ".").compactMap { Int($0) }

        let major = components.count > 0 ? components[0] : 0
        let minor = components.count > 1 ? components[1] : 0
        let patch = components.count > 2 ? components[2] : 0

        return major * 10000 + minor * 100 + patch
    }

    /// Extracts the first markdown image URL from the body
    /// Looks for patterns like ![alt](url) or <img src="url">
    private func extractFirstImage(from body: String?) -> URL? {
        guard let body = body else { return nil }

        // Match markdown image: ![...](url)
        let markdownPattern = #"!\[.*?\]\((https?://[^\s\)]+)\)"#
        if let match = body.range(of: markdownPattern, options: .regularExpression),
           let urlStart = body[match].range(of: "(http"),
           let urlEnd = body[match].range(of: ")", range: urlStart.lowerBound..<body[match].endIndex) {
            let urlString = String(body[urlStart.lowerBound..<urlEnd.lowerBound]).dropFirst()
            return URL(string: String(urlString))
        }

        // Match HTML img tag: <img src="url">
        let htmlPattern = #"<img[^>]+src=[\"'](https?://[^\"']+)[\"']"#
        if let match = body.range(of: htmlPattern, options: .regularExpression) {
            let matchedString = String(body[match])
            if let srcStart = matchedString.range(of: "src="),
               let quote = matchedString[srcStart.upperBound...].first,
               (quote == "\"" || quote == "'") {
                let afterQuote = matchedString.index(after: srcStart.upperBound)
                if let endQuote = matchedString[afterQuote...].firstIndex(of: quote) {
                    return URL(string: String(matchedString[afterQuote..<endQuote]))
                }
            }
        }

        return nil
    }
}
