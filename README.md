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
    checkInterval: .seconds(24 * 60 * 60), // Daily checks
    backgroundTimeout: .seconds(60)         // Timeout for background checks
)

// Enable beta updates (persisted across app restarts)
twinkle.allowPrereleases = true

// Ignore a specific version
twinkle.ignoreVersion("2.0.0")

// Cancel an in-progress download
twinkle.cancelDownload()
```

## Requirements

- **Code signing must match** - The downloaded app must be signed with the same identity as the running app
- **Version must increment** - New releases need a higher semver (e.g., `v1.0.0` → `v1.1.0`)
- **Include a `.zip` asset** - Releases without a `.zip` file are ignored
- **Single app per archive** - The `.zip` must contain exactly one `.app` bundle

## Error Handling

Twinkle provides specific error types for different failure scenarios:

```swift
switch error {
case .invalidBundle:
    // No valid .app found in download
case .codeSigningMismatch:
    // Downloaded app signed with different identity
case .versionMismatch(let expected, let actual):
    // Bundle version doesn't match release
case .downloadFailed(let reason):
    // Network or file system error during download
case .downloadCancelled:
    // User cancelled the download
case .diskSpaceLow(let required, let available):
    // Insufficient disk space for download
case .rateLimited(let retryAfter):
    // GitHub API rate limit hit
case .installationFailed(let reason):
    // Error during app replacement
case .multipleAppsFound(let count):
    // Archive contains more than one .app
case .networkError(let code):
    // URLSession error
}
```

## How Version Comparison Works

Twinkle compares releases using **build numbers** computed from semantic versions:

```
v1.0.0  → 10000 (1×10000 + 0×100 + 0)
v1.2.3  → 10203 (1×10000 + 2×100 + 3)
v2.0.0  → 20000 (2×10000 + 0×100 + 0)
```

For non-semver tags, releases are compared by their published date.

## Thread Safety

- `Twinkle` is marked `@MainActor` - all property access and method calls happen on the main thread
- State updates are always delivered on the main thread via `@Observable`
- Background operations (downloads, extraction, code signing) run on background queues
- Multiple concurrent `check()` calls are prevented automatically

## Troubleshooting

**Update not detected**
- Verify the release has a `.zip` asset attached
- Check that the new version has a higher build number
- Ensure the release is not a prerelease (unless `allowPrereleases = true`)

**Code signing mismatch**
- Both apps must be signed with the same Developer ID or development certificate
- Check `codesign -dvvv YourApp.app` for both versions

**Installation fails**
- Ensure the app has write permission to its own location
- Twinkle creates a backup before replacing; check for `.twinkle-backup-*` files

**Rate limited**
- GitHub allows 60 unauthenticated requests/hour
- Wait for the retry-after period or reduce check frequency
