import SwiftUI
import Twinkle

struct ContentView: View {
    @Bindable var twinkle: Twinkle

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Twinkle Example")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            Group {
                HStack {
                    Text("Current Version:")
                    Spacer()
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build Number:")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("State:")
                    Spacer()
                    Text(stateDescription)
                        .foregroundStyle(stateColor)
                }
            }
            .font(.body)

            Divider()

            stateView

            Spacer()

            if !twinkle.releases.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Releases:")
                        .font(.headline)
                    ForEach(twinkle.releases.prefix(3)) { release in
                        HStack {
                            Text("v\(release.version)")
                            if release.prerelease {
                                Text("beta")
                                    .font(.caption)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Spacer()
                            Text("Build \(release.buildNumber)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 450)
    }

    @ViewBuilder
    private var stateView: some View {
        switch twinkle.state {
        case .idle:
            Button("Check for Updates") {
                Task { await twinkle.check() }
            }
            .buttonStyle(.borderedProminent)

        case .checking:
            ProgressView("Checking for updates...")

        case .available(let release):
            VStack(spacing: 12) {
                Text("Update Available: v\(release.version)")
                    .font(.headline)
                    .foregroundStyle(.green)

                if !release.changelog.isEmpty {
                    ScrollView {
                        Text(release.changelog)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                    .padding(8)
                    .background(.secondary.opacity(0.1))
                    .cornerRadius(8)
                }

                HStack {
                    Button("Download") {
                        Task { try? await twinkle.download(release: release) }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Skip This Version") {
                        twinkle.ignoreVersion(release.version)
                    }
                    .buttonStyle(.bordered)
                }
            }

        case .downloading(let release, let progress):
            VStack(spacing: 12) {
                Text("Downloading v\(release.version)...")
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Cancel") {
                    twinkle.cancelDownload()
                }
                .buttonStyle(.bordered)
            }

        case .ready(let release, _):
            VStack(spacing: 12) {
                Text("Ready to Install v\(release.version)")
                    .font(.headline)
                    .foregroundStyle(.green)

                Button("Install & Restart") {
                    Task { try? await twinkle.install() }
                }
                .buttonStyle(.borderedProminent)
            }

        case .upToDate:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("You're up to date!")
                    .foregroundStyle(.secondary)

                Button("Check Again") {
                    Task { await twinkle.check() }
                }
                .buttonStyle(.bordered)
            }

        case .installing:
            VStack(spacing: 8) {
                ProgressView()
                Text("Installing update...")
            }

        case .failed(let error):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Update Failed")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task { await twinkle.check() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var stateDescription: String {
        switch twinkle.state {
        case .idle: "Idle"
        case .checking: "Checking..."
        case .available: "Update Available"
        case .downloading: "Downloading..."
        case .ready: "Ready to Install"
        case .upToDate: "Up to Date"
        case .installing: "Installing..."
        case .failed: "Failed"
        }
    }

    private var stateColor: Color {
        switch twinkle.state {
        case .idle: .secondary
        case .checking: .blue
        case .available: .green
        case .downloading: .blue
        case .ready: .green
        case .upToDate: .green
        case .installing: .blue
        case .failed: .red
        }
    }
}

#Preview {
    ContentView(twinkle: Twinkle(owner: "Aayush9029", repo: "twinkle"))
}
