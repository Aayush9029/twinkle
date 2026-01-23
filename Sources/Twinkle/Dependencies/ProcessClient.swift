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
            let process = Process()
            process.currentDirectoryURL = destination
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", archive.path]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw TwinkleError.unzipFailed("Exit code: \(process.terminationStatus)")
            }
        },

        codeSigningIdentity: { bundlePath in
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

            return output
                .split(separator: "\n")
                .first { $0.hasPrefix("Authority=") }
                .map { String($0.dropFirst(10)) }
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
