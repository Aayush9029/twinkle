import Foundation
import Twinkle

extension UpdateState {
    var demoTitle: String {
        switch self {
        case .idle:
            "Waiting"
        case .checking:
            "Checking for releases"
        case .upToDate:
            "No update available"
        case .available(let release):
            "\(release.version) available"
        case .downloading(let release, _):
            "Downloading \(release.version)"
        case .ready(let release, _):
            "\(release.version) ready"
        case .installing:
            "Installing update"
        case .failed:
            "Update check failed"
        }
    }

    var demoDetail: String {
        switch self {
        case .idle:
            "The updater is not doing work."
        case .checking:
            "GitHub releases are being fetched for the configured repository."
        case .upToDate:
            "The current build is newer than the latest eligible release."
        case .available(let release):
            "Build \(release.buildNumber) is eligible and can be downloaded."
        case .downloading(_, let progress):
            "Download progress is \(progress.formatted(.percent.precision(.fractionLength(0))))."
        case .ready(_, let bundle):
            "The validated app bundle is ready at \(bundle.lastPathComponent)."
        case .installing:
            "The downloaded app is replacing the current bundle."
        case .failed(let error):
            error.localizedDescription
        }
    }

    var demoProgress: Double? {
        guard case .downloading(_, let progress) = self else {
            return nil
        }

        return progress
    }
}
