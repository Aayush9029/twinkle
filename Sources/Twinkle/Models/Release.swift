import Foundation
import IdentifiedCollections

public struct Release: Identifiable, Codable, Sendable, Hashable {
    public var id: String { version }

    public let buildNumber: Int
    public let version: String
    public let changelog: String
    public let zipUrl: URL
    public let prerelease: Bool
    public let publishedAt: Date?

    public var kind: Kind { prerelease ? .prerelease(zipUrl) : .stable(zipUrl) }

    public init(
        buildNumber: Int,
        version: String,
        changelog: String,
        zipUrl: URL,
        prerelease: Bool,
        publishedAt: Date? = nil
    ) {
        self.buildNumber = buildNumber
        self.version = version
        self.changelog = changelog
        self.zipUrl = zipUrl
        self.prerelease = prerelease
        self.publishedAt = publishedAt
    }
}

// MARK: - Release.Kind

extension Release {
    public enum Kind: Sendable, Hashable {
        case stable(URL)
        case prerelease(URL)

        public var url: URL {
            switch self {
            case .stable(let url), .prerelease(let url):
                return url
            }
        }
    }
}

// MARK: - Comparable by build number, then by date

extension Release: Comparable {
    public static func < (lhs: Release, rhs: Release) -> Bool {
        // Primary: compare by build number
        if lhs.buildNumber != rhs.buildNumber {
            return lhs.buildNumber < rhs.buildNumber
        }
        // Fallback: compare by published date (for non-semver tags)
        if let lhsDate = lhs.publishedAt, let rhsDate = rhs.publishedAt {
            return lhsDate < rhsDate
        }
        return false
    }
}

// MARK: - Previews

extension Release {
    public static let preview = Release(
        buildNumber: 100,
        version: "2.0.0",
        changelog: "### What's New\n- New features and improvements\n- Bug fixes",
        zipUrl: URL(string: "https://example.com/releases/2.0.0.zip")!,
        prerelease: false
    )

    public static let preview2 = Release(
        buildNumber: 99,
        version: "1.5.0",
        changelog: "Bug fixes and stability improvements",
        zipUrl: URL(string: "https://example.com/releases/1.5.0.zip")!,
        prerelease: false
    )

    public static let previewBeta = Release(
        buildNumber: 101,
        version: "2.1.0-beta",
        changelog: "### Beta Release\n- Experimental features",
        zipUrl: URL(string: "https://example.com/releases/2.1.0-beta.zip")!,
        prerelease: true
    )
}
