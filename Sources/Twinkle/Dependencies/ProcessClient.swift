import Foundation
import Dependencies
import DependenciesMacros

/// Client for shell commands (unzip, codesign)
@DependencyClient
public struct ProcessClient: Sendable {
    public var unzip: @Sendable (_ archive: URL, _ destination: URL) async throws -> Void
    public var codeSigningIdentity: @Sendable (_ bundlePath: String) async throws -> String?
}

extension DependencyValues {
    public var processClient: ProcessClient {
        get { self[ProcessClient.self] }
        set { self[ProcessClient.self] = newValue }
    }
}

extension ProcessClient: DependencyKey {
    public static let liveValue = ProcessClient(
        unzip: { archive, destination in
            // Run on background to avoid blocking MainActor
            try await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.currentDirectoryURL = destination
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-o", archive.path]

                let stderr = Pipe()
                process.standardError = stderr

                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    throw TwinkleError.unzipFailed(errorMessage ?? "Exit code: \(process.terminationStatus)")
                }
            }.value
        },

        codeSigningIdentity: { bundlePath in
            // Run on background to avoid blocking MainActor
            try await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                process.arguments = ["-dvvv", bundlePath]

                let stderr = Pipe()
                process.standardError = stderr

                try process.run()
                process.waitUntilExit()

                let data = stderr.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    return nil
                }

                // Extract all Authority= lines (certificate chain)
                // First Authority is the leaf certificate (signing identity)
                let authorities = output
                    .split(separator: "\n")
                    .filter { $0.hasPrefix("Authority=") }
                    .map { String($0.dropFirst(10)) }

                return authorities.first
            }.value
        }
    )

    public static let previewValue = ProcessClient(
        unzip: { _, _ in
            try await Task.sleep(for: .milliseconds(100))
        },
        codeSigningIdentity: { _ in
            "Apple Development: Mock Developer (MOCKTEAMID)"
        }
    )

    public static let testValue = ProcessClient()
}
