import Twinkle

enum TwinkleDemoSmokeTest {
    @MainActor
    static func run() {
        let model = TwinkleDemoModel()

        precondition(model.twinkle.slug == "Aayush9029/twinkle")
        precondition(model.selectedState.release == Release.preview)
        precondition(model.selectedState.demoTitle == "2.0.0 available")

        print("TwinkleDemo smoke test passed")
    }
}
