<div align="center">

<img src="assets/twinkle-icon.png" width="128">

<h2> Twinkle </h2>

A lightweight auto-updater for macOS apps that checks GitHub releases for updates.
    
[![CI](https://github.com/Aayush9029/twinkle/actions/workflows/ci.yml/badge.svg)](https://github.com/Aayush9029/twinkle/actions/workflows/ci.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)
    
</div>

## Installation

Add Twinkle to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Aayush9029/twinkle.git", from: "1.0.0")
]
```

## Usage

### Basic Setup

```swift
import Twinkle

@main
struct MyApp: App {
    @State private var twinkle = Twinkle(owner: "Aayush9029", repo: "MyApp")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(twinkle)
        }
    }
}
```

### Check for Updates

```swift
struct SettingsView: View {
    @Environment(Twinkle.self) var twinkle

    var body: some View {
        Button("Check for Updates") {
            Task { await twinkle.check() }
        }
    }
}
```

### Update States

```swift
switch twinkle.state {
case .idle: Text("Check for updates")
case .checking: ProgressView()
case .upToDate: Text("Up to date")
case .available(let release): Text("v\(release.version) available")
case .downloading(_, let progress): ProgressView(value: progress)
case .ready: Button("Install") { Task { try await twinkle.install() } }
case .installing: ProgressView()
case .failed(let error): Text(error.localizedDescription)
}
```

## How It Works

Fetches GitHub releases → Downloads `.zip` asset → Validates code signing → Installs & relaunches

## GitHub Release Setup

1. Tag with semver: `v2.0.0`
2. Attach `.zip` of your app
3. Write changelog in release body

## Configuration

```swift
let twinkle = Twinkle(
    owner: "Aayush9029",
    repo: "MyApp",
    checkInterval: .seconds(24 * 60 * 60) // Daily checks
)

// Enable beta updates
twinkle.allowPrereleases = true

// Ignore a specific version
twinkle.ignoreVersion("2.0.0")
```

## License

MIT
