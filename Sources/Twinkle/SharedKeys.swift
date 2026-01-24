import Foundation
import Sharing

// MARK: - Shared State Keys

extension SharedKey where Self == AppStorageKey<Date?>.Default {
    /// Last update check timestamp
    public static var lastUpdateCheck: Self {
        Self[.appStorage("twinkle:lastUpdateCheck"), default: nil]
    }
}

extension SharedKey where Self == AppStorageKey<String?>.Default {
    /// Version user chose to skip
    public static var ignoredVersion: Self {
        Self[.appStorage("twinkle:ignoredVersion"), default: nil]
    }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    /// Whether to include prerelease/beta updates
    public static var betaUpdatesEnabled: Self {
        Self[.appStorage("twinkle:betaUpdatesEnabled"), default: false]
    }
}

