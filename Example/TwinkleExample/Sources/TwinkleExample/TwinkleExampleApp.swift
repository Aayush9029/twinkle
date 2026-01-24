import SwiftUI
import Twinkle

@main
struct TwinkleExampleApp: App {
    @State private var twinkle = Twinkle(owner: "Aayush9029", repo: "twinkle")

    var body: some Scene {
        WindowGroup {
            ContentView(twinkle: twinkle)
        }
    }
}
