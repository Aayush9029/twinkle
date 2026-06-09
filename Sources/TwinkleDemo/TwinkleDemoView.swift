import SwiftUI

struct TwinkleDemoView: View {
    @State private var model = TwinkleDemoModel()

    var body: some View {
        NavigationSplitView {
            Form {
                repositorySection
                stateSection
            }
            .formStyle(.grouped)
            .navigationTitle("Twinkle")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    progressView
                    releaseSummary
                    librarySummary
                }
                .padding(32)
                .frame(maxWidth: 720, alignment: .topLeading)
            }
            .navigationTitle(model.selectedSample.title)
        }
        .frame(minWidth: 820, minHeight: 540)
    }

    private var repositorySection: some View {
        Section("Repository") {
            LabeledContent("Slug", value: model.twinkle.slug)
            Toggle("Prereleases", isOn: $model.allowPrereleases)
        }
    }

    private var stateSection: some View {
        Section("Update State") {
            Picker("Preview", selection: $model.selectedSample) {
                ForEach(TwinkleDemoStateSample.allCases) { sample in
                    Label(sample.title, systemImage: sample.symbolName)
                        .tag(sample)
                }
            }
            .pickerStyle(.inline)

            Button {
                model.nextStateButtonTapped()
            } label: {
                Label("Next State", systemImage: "arrow.right")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.selectedSample.title, systemImage: model.selectedSample.symbolName)
                .font(.title2.weight(.semibold))

            Text(model.selectedState.demoTitle)
                .font(.title.weight(.bold))

            Text(model.selectedState.demoDetail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var progressView: some View {
        if let progress = model.selectedState.demoProgress {
            ProgressView(value: progress) {
                Text("Download")
            } currentValueLabel: {
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
            }
        }
    }

    @ViewBuilder
    private var releaseSummary: some View {
        if let release = model.release {
            GroupBox("Release") {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Text(release.version)
                    }

                    GridRow {
                        Text("Build")
                            .foregroundStyle(.secondary)
                        Text(release.buildNumber.formatted())
                    }

                    GridRow {
                        Text("Kind")
                            .foregroundStyle(.secondary)
                        Text(release.prerelease ? "Prerelease" : "Stable")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
    }

    private var librarySummary: some View {
        GroupBox("Library Instance") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    Text("Repository")
                        .foregroundStyle(.secondary)
                    Text(model.twinkle.slug)
                }

                GridRow {
                    Text("Prereleases")
                        .foregroundStyle(.secondary)
                    Text(model.allowPrereleases ? "Enabled" : "Disabled")
                }

                GridRow {
                    Text("Runtime state")
                        .foregroundStyle(.secondary)
                    Text(model.twinkle.state.demoTitle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    TwinkleDemoView()
}
