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
        #expect(TwinkleError.downloadCancelled.errorDescription == "Download cancelled")
        #expect(TwinkleError.unzipFailed("corrupt").errorDescription == "Unzip failed: corrupt")
        #expect(TwinkleError.networkError(.notConnectedToInternet).errorDescription == "Network error: -1009")
        #expect(TwinkleError.installationFailed("permission denied").errorDescription == "Installation failed: permission denied")
        #expect(TwinkleError.multipleAppsFound(3).errorDescription == "Found 3 apps in archive, expected 1")
    }

    @Test("Disk space error formats bytes correctly")
    func diskSpaceFormatting() {
        let error = TwinkleError.diskSpaceLow(required: 1_073_741_824, available: 536_870_912)
        let description = error.errorDescription ?? ""
        #expect(description.contains("GB"))
        #expect(description.contains("required"))
        #expect(description.contains("available"))
    }

    @Test("Rate limit error shows retry time")
    func rateLimitWithRetry() {
        let errorWithRetry = TwinkleError.rateLimited(retryAfter: 60)
        #expect(errorWithRetry.errorDescription?.contains("60 seconds") == true)

        let errorWithoutRetry = TwinkleError.rateLimited(retryAfter: nil)
        #expect(errorWithoutRetry.errorDescription?.contains("later") == true)
    }

    @Test("Errors are equatable")
    func equality() {
        #expect(TwinkleError.invalidBundle == TwinkleError.invalidBundle)
        #expect(TwinkleError.downloadFailed("a") == TwinkleError.downloadFailed("a"))
        #expect(TwinkleError.downloadFailed("a") != TwinkleError.downloadFailed("b"))
        #expect(TwinkleError.networkError(.badURL) == TwinkleError.networkError(.badURL))
        #expect(TwinkleError.downloadCancelled == TwinkleError.downloadCancelled)
        #expect(TwinkleError.diskSpaceLow(required: 100, available: 50) == TwinkleError.diskSpaceLow(required: 100, available: 50))
        #expect(TwinkleError.rateLimited(retryAfter: 60) == TwinkleError.rateLimited(retryAfter: 60))
        #expect(TwinkleError.rateLimited(retryAfter: 60) != TwinkleError.rateLimited(retryAfter: 30))
    }

    @Test("Errors conform to Error protocol")
    func errorProtocol() {
        let error: Error = TwinkleError.invalidBundle
        #expect(error.localizedDescription.isEmpty == false)
    }

    @Test("Version mismatch shows expected and actual")
    func versionMismatch() {
        let errorWithActual = TwinkleError.versionMismatch(expected: "2.0.0", actual: "1.9.0")
        #expect(errorWithActual.errorDescription?.contains("2.0.0") == true)
        #expect(errorWithActual.errorDescription?.contains("1.9.0") == true)

        let errorWithNil = TwinkleError.versionMismatch(expected: "2.0.0", actual: nil)
        #expect(errorWithNil.errorDescription?.contains("unknown") == true)
    }
}
