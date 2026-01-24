import Testing
import Foundation
@testable import Twinkle

@Suite("UpdateState Tests")
struct UpdateStateTests {

    @Test("isChecking is true only for checking state")
    func isChecking() {
        #expect(UpdateState.idle.isChecking == false)
        #expect(UpdateState.checking.isChecking == true)
        #expect(UpdateState.upToDate.isChecking == false)
        #expect(UpdateState.available(.preview).isChecking == false)
    }

    @Test("release extracts from relevant states")
    func releaseProperty() {
        #expect(UpdateState.idle.release == nil)
        #expect(UpdateState.checking.release == nil)
        #expect(UpdateState.available(.preview).release == .preview)
        #expect(UpdateState.downloading(.preview2, progress: 0.5).release == .preview2)
        #expect(UpdateState.ready(.previewBeta, bundle: URL(fileURLWithPath: "/")).release == .previewBeta)
        #expect(UpdateState.installing.release == nil)
        #expect(UpdateState.failed(.invalidBundle).release == nil)
    }

    @Test("States with same values are equal")
    func equality() {
        #expect(UpdateState.idle == UpdateState.idle)
        #expect(UpdateState.checking == UpdateState.checking)
        #expect(UpdateState.available(.preview) == UpdateState.available(.preview))
        #expect(UpdateState.downloading(.preview, progress: 0.5) == UpdateState.downloading(.preview, progress: 0.5))
        #expect(UpdateState.failed(.invalidBundle) == UpdateState.failed(.invalidBundle))
    }

    @Test("States with different values are not equal")
    func inequality() {
        #expect(UpdateState.idle != UpdateState.checking)
        #expect(UpdateState.available(.preview) != UpdateState.available(.preview2))
        #expect(UpdateState.downloading(.preview, progress: 0.5) != UpdateState.downloading(.preview, progress: 0.7))
    }

    @Test("upToDate has no release")
    func upToDateNoRelease() {
        #expect(UpdateState.upToDate.release == nil)
    }

    @Test("installing has no release")
    func installingNoRelease() {
        #expect(UpdateState.installing.release == nil)
    }
}
