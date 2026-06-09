import Darwin
import SwiftUI

@main
struct TwinkleDemoApp: App {
    init() {
        guard CommandLine.arguments.contains("--smoke-test") else {
            return
        }

        Task { @MainActor in
            TwinkleDemoSmokeTest.run()
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        WindowGroup {
            TwinkleDemoView()
        }
    }
}
