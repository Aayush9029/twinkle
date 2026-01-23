import Testing
import Foundation
@testable import Twinkle

@Suite("TwinkleError Tests")
struct TwinkleErrorTests {

    @Test("Errors have localized descriptions")
    func localizedDescriptions() {
        #expect(TwinkleError.invalidBundle.errorDescription == "Invalid bundle")
        #expect(TwinkleError.codeSigningMismatch.errorDescription == "Code signing mismatch")
        #expect(TwinkleError.downloadFailed("timeout").errorDescription == "Download failed: timeout")
        #expect(TwinkleError.unzipFailed("corrupt").errorDescription == "Unzip failed: corrupt")
        #expect(TwinkleError.networkError(.notConnectedToInternet).errorDescription == "Network error: -1009")
    }

    @Test("Errors are equatable")
    func equality() {
        #expect(TwinkleError.invalidBundle == TwinkleError.invalidBundle)
        #expect(TwinkleError.downloadFailed("a") == TwinkleError.downloadFailed("a"))
        #expect(TwinkleError.downloadFailed("a") != TwinkleError.downloadFailed("b"))
        #expect(TwinkleError.networkError(.badURL) == TwinkleError.networkError(.badURL))
    }

    @Test("Errors conform to Error protocol")
    func errorProtocol() {
        let error: Error = TwinkleError.invalidBundle
        #expect(error.localizedDescription.isEmpty == false)
    }
}
