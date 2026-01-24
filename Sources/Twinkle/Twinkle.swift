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
    @ObservationIgnored
    @Shared(.betaUpdatesEnabled) private var _allowPrereleases

    // MARK: - Configuration
    public let owner: String
    public let repo: String

    /// Whether to include prerelease/beta updates (persisted)
    public var allowPrereleases: Bool {
        get { _allowPrereleases }
        set { $_allowPrereleases.withLock { $0 = newValue } }
    }

    // MARK: - State
    public private(set) var state: UpdateState = .idle
    public private(set) var releases: IdentifiedArrayOf<Release> = []

    // MARK: - Internal
    @ObservationIgnored
    private let activity: NSBackgroundActivityScheduler

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.twinkle.updater", category: "main")

    @ObservationIgnored
    private var downloadTask: Task<Void, Error>?

    @ObservationIgnored
    private let backgroundTimeout: Duration

    public var slug: String {
        "\(owner)/\(repo)"
    }

    // MARK: - Initialization
    public init(
        owner: String,
        repo: String,
        checkInterval: Duration = .seconds(24 * 60 * 60),
        backgroundTimeout: Duration = .seconds(60)
    ) {
        self.owner = owner
        self.repo = repo
        self.backgroundTimeout = backgroundTimeout

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

        downloadTask = Task {
            for try await progress in releaseClient.downloadZip(release.zipUrl, downloadPath) {
                try Task.checkCancellation()
                switch progress {
                case .downloading(let fraction, _, _):
                    state = .downloading(release, progress: fraction)

                case .completed(let savedTo):
                    let bundleURL = try await extractAndValidate(archive: savedTo, expectedRelease: release)
                    state = .ready(release, bundle: bundleURL)
                }
            }
        }

        do {
            try await downloadTask?.value
        } catch is CancellationError {
            throw TwinkleError.downloadCancelled
        }
    }

    /// Cancel an in-progress download
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        if case .downloading = state {
            state = .idle
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

        // Create backup before replacing (rollback safety)
        let backupURL = currentBundleURL.deletingLastPathComponent()
            .appendingPathComponent(".twinkle-backup-\(currentBundleURL.lastPathComponent)")

        do {
            // Remove any previous backup
            try? FileManager.default.removeItem(at: backupURL)

            // Move current app to backup location
            try FileManager.default.moveItem(at: currentBundleURL, to: backupURL)

            // Move new app to current location
            do {
                try FileManager.default.moveItem(at: bundleURL, to: currentBundleURL)
            } catch {
                // Rollback: restore from backup
                logger.error("Installation failed, rolling back: \(error)")
                try? FileManager.default.moveItem(at: backupURL, to: currentBundleURL)
                throw TwinkleError.installationFailed(error.localizedDescription)
            }

            // Clean up backup after successful move
            try? FileManager.default.removeItem(at: backupURL)

        } catch let error as TwinkleError {
            throw error
        } catch {
            throw TwinkleError.installationFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = finalExe
        try process.run()

        NSApp.terminate(nil)
    }

    // MARK: - Private Helpers

    private func setupBackgroundActivity() {
        activity.schedule { [weak self] completion in
            guard let self else {
                completion(.deferred)
                return
            }

            Task { @MainActor in
                // Add timeout to prevent hanging indefinitely
                let checkTask = Task {
                    await self.check()
                }

                let timeoutTask = Task {
                    try await Task.sleep(for: self.backgroundTimeout)
                    checkTask.cancel()
                }

                _ = await checkTask.result
                timeoutTask.cancel()

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

        let appURLs = contents.filter { $0.pathExtension == "app" }

        guard !appURLs.isEmpty else {
            throw TwinkleError.invalidBundle
        }

        // Warn if multiple apps found (ambiguous)
        if appURLs.count > 1 {
            logger.warning("Found \(appURLs.count) apps in archive, using first one")
            throw TwinkleError.multipleAppsFound(appURLs.count)
        }

        let appURL = appURLs[0]

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

