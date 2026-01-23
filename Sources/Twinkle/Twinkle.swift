import Foundation
import AppKit
import Dependencies
import IdentifiedCollections
import OSLog
import Sharing

@Observable
@MainActor
public final class Twinkle {
    // MARK: - Dependencies
    @ObservationIgnored
    @Dependency(\.releaseClient) private var releaseClient
    @ObservationIgnored
    @Dependency(\.processClient) private var processClient
    @ObservationIgnored
    @Dependency(\.bundleInfo) private var bundleInfo

    // MARK: - Shared State
    @ObservationIgnored
    @Shared(.lastUpdateCheck) private var lastUpdateCheck
    @ObservationIgnored
    @Shared(.ignoredVersion) private var ignoredVersion

    // MARK: - Configuration
    public let owner: String
    public let repo: String

    public var allowPrereleases: Bool = false

    // MARK: - State
    public private(set) var state: UpdateState = .idle
    public private(set) var releases: IdentifiedArrayOf<Release> = []

    // MARK: - Internal
    @ObservationIgnored
    private let activity: NSBackgroundActivityScheduler

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.twinkle.updater", category: "main")

    public var slug: String {
        "\(owner)/\(repo)"
    }

    // MARK: - Initialization
    public init(
        owner: String,
        repo: String,
        checkInterval: Duration = .seconds(24 * 60 * 60)
    ) {
        self.owner = owner
        self.repo = repo

        self.activity = NSBackgroundActivityScheduler(
            identifier: "Twinkle.\(Bundle.main.bundleIdentifier ?? "")"
        )
        activity.repeats = true
        activity.interval = TimeInterval(checkInterval.components.seconds)

        setupBackgroundActivity()
    }

    deinit {
        activity.invalidate()
    }

    // MARK: - Public API

    public func check() async {
        guard !state.isChecking else { return }

        state = .checking
        logger.info("Checking for updates: \(self.slug)")

        do {
            let fetchedReleases = try await releaseClient.fetchReleases(owner, repo)
            releases = fetchedReleases
            $lastUpdateCheck.withLock { $0 = Date() }

            let currentBuildNumber = bundleInfo.bundleVersion().flatMap(Int.init) ?? 0

            guard let release = findViableUpdate(
                in: fetchedReleases,
                currentBuildNumber: currentBuildNumber
            ) else {
                state = .upToDate
                logger.info("Already up to date: build \(currentBuildNumber)")
                return
            }

            logger.info("New version available: \(release.version) (build \(release.buildNumber))")
            state = .available(release)

            try await download(release: release)

        } catch {
            logger.error("Update check failed: \(error)")
            state = .failed(mapError(error))
        }
    }

    public func download(release: Release) async throws {
        let tmpDir = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: Bundle.main.bundleURL,
            create: true
        )
        let downloadPath = tmpDir.appendingPathComponent("download.zip")

        for try await progress in releaseClient.downloadZip(release.zipUrl, downloadPath) {
            switch progress {
            case .downloading(let fraction):
                state = .downloading(release, progress: fraction)

            case .completed(let savedTo):
                let bundleURL = try await extractAndValidate(archive: savedTo, expectedRelease: release)
                state = .ready(release, bundle: bundleURL)
            }
        }
    }

    public func install() async throws {
        guard case .ready(_, let bundleURL) = state else {
            throw TwinkleError.invalidBundle
        }

        state = .installing

        guard let downloadedBundle = Bundle(url: bundleURL),
              let exe = downloadedBundle.executableURL,
              FileManager.default.fileExists(atPath: exe.path) else {
            throw TwinkleError.invalidBundle
        }

        let currentBundleURL = Bundle.main.bundleURL
        let finalExe = currentBundleURL
            .appendingPathComponent("Contents/MacOS/\(exe.lastPathComponent)", isDirectory: false)

        try FileManager.default.removeItem(at: currentBundleURL)
        try FileManager.default.moveItem(at: bundleURL, to: currentBundleURL)

        let process = Process()
        process.executableURL = finalExe
        try process.run()

        NSApp.terminate(nil)
    }

    // MARK: - Private Helpers

    private func setupBackgroundActivity() {
        activity.schedule { [weak self] completion in
            guard let self, !self.activity.shouldDefer else {
                completion(.deferred)
                return
            }

            Task { @MainActor in
                await self.check()
                completion(.finished)
            }
        }
    }

    private func findViableUpdate(
        in releases: IdentifiedArrayOf<Release>,
        currentBuildNumber: Int
    ) -> Release? {
        let candidates = allowPrereleases ? Array(releases) : releases.filter { !$0.prerelease }

        guard let latest = candidates.max(),
              currentBuildNumber < latest.buildNumber,
              ignoredVersion != latest.version else {
            return nil
        }

        return latest
    }

    /// Mark a version as ignored so it won't show as an available update
    public func ignoreVersion(_ version: String) {
        $ignoredVersion.withLock { $0 = version }
        if case .available(let release) = state, release.version == version {
            state = .upToDate
        }
    }

    /// Clear the ignored version
    public func clearIgnoredVersion() {
        $ignoredVersion.withLock { $0 = nil }
    }

    private func extractAndValidate(archive: URL, expectedRelease: Release) async throws -> URL {
        let extractDir = archive.deletingLastPathComponent()

        try await processClient.unzip(archive, extractDir)

        let contents = try FileManager.default.contentsOfDirectory(
            at: extractDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw TwinkleError.invalidBundle
        }

        // Sanity check: verify the extracted bundle version matches expected
        if let extractedBundle = Bundle(url: appURL) {
            let actualVersion = extractedBundle.infoDictionary?["CFBundleShortVersionString"] as? String
            if actualVersion != expectedRelease.version {
                logger.warning("Version mismatch: expected \(expectedRelease.version), got \(actualVersion ?? "nil")")
                throw TwinkleError.versionMismatch(expected: expectedRelease.version, actual: actualVersion)
            }
        }

        try await validateCodeSigning(appURL)

        return appURL
    }

    private func validateCodeSigning(_ bundleURL: URL) async throws {
        let currentIdentity = try await processClient.codeSigningIdentity(Bundle.main.bundlePath)
        let downloadedIdentity = try await processClient.codeSigningIdentity(bundleURL.path)

        guard currentIdentity == downloadedIdentity else {
            throw TwinkleError.codeSigningMismatch
        }
    }

    private func mapError(_ error: Error) -> TwinkleError {
        if let twinkleError = error as? TwinkleError {
            return twinkleError
        }
        if let urlError = error as? URLError {
            return .networkError(urlError.code)
        }
        return .downloadFailed(error.localizedDescription)
    }
}

