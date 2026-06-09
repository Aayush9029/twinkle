import Observation
import Twinkle

@MainActor
@Observable
final class TwinkleDemoModel {
    let twinkle: Twinkle
    var selectedSample: TwinkleDemoStateSample = .available
    var allowPrereleases: Bool {
        didSet {
            twinkle.allowPrereleases = allowPrereleases
        }
    }

    init() {
        let twinkle = Twinkle(owner: "Aayush9029", repo: "twinkle")
        self.twinkle = twinkle
        self.allowPrereleases = twinkle.allowPrereleases
    }

    init(twinkle: Twinkle) {
        self.twinkle = twinkle
        self.allowPrereleases = twinkle.allowPrereleases
    }

    var selectedState: UpdateState {
        selectedSample.state
    }

    var release: Release? {
        selectedState.release
    }

    func nextStateButtonTapped() {
        let samples = TwinkleDemoStateSample.allCases
        guard let index = samples.firstIndex(of: selectedSample) else {
            selectedSample = samples[0]
            return
        }

        selectedSample = samples[(index + 1) % samples.count]
    }
}
