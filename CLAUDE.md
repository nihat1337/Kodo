# Kodo

A QR code app for iOS: create styled codes (website, contact, Wi-Fi, email, SMS,
location) and scan QR codes and barcodes. Four tabs: Scan, Create, History, Settings.

## Hard rules

**SwiftUI only.** No `UIViewRepresentable`, no `UIViewControllerRepresentable`, no
UIKit types in signatures — not even ones SwiftUI re-exports (take the keyboard type
at the call site rather than passing a `UIKeyboardType`). The camera preview is
`AVCaptureVideoDataOutput` frames drawn as a SwiftUI `Image`, not a preview layer.

The **only** exception is `Services/System/Clipboard.swift`, which imports UIKit
because `UIPasteboard` is the only clipboard on iOS. No UIKit type crosses its
boundary. `grep -rl "import UIKit" Kodo/` must return that one file.

AVFoundation, Vision, Contacts, NetworkExtension, AudioToolbox, Core Image, Core
Graphics and ImageIO are all fine — they are not UIKit.

**No comments in the source.** Files carry the Xcode header and nothing else. Do not
add explanatory comments, `// MARK:` dividers or doc comments; the owner strips them.
Explain in the chat instead.

**British-ish plain English in user-facing strings.** Short, no exclamation marks.

## Architecture

MVVM by folder, with one rule that keeps it honest:

> Services know nothing about SwiftUI. Views know nothing about AVFoundation or
> Core Image. The ViewModel is the only translator.

That is why services return `CGImage` rather than `Image`, and why `DetectedCode`
exists instead of passing AVFoundation types up.

```
Kodo/
├── KodoApp.swift              @main, SwiftData container, settings defaults
├── ContentView.swift          the four tabs
├── Models/                    plain data: CodeRecord (@Model), QRType, QRStyle,
│                              ScannedContent, DetectedCode, SettingsKey
├── ViewModels/                GeneratorViewModel, ScannerViewModel (@Observable)
├── Views/                     one per screen + CodeDetailView, shared by Scan and History
└── Services/
    ├── Creating/              QRCodeGenerator, QRPayloadBuilder
    ├── Scanning/              CameraScanner, PhotoQRDecoder, ScannedContentParser
    ├── Results/               LinkSafety, WiFiJoiner, ContactSaver, HistoryExporter
    └── System/                Clipboard, SoundPlayer
```

`QRPayloadBuilder` and `ScannedContentParser` are mirrors of each other. Change one
format and change the other, then round-trip test it.

## Build and run

```bash
xcodebuild -project Kodo.xcodeproj -scheme Kodo \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

xcrun simctl install "iPhone 17" <path>/Kodo.app
xcrun simctl launch  "iPhone 17" nihadlocal.Kodo
```

The build must end `BUILD SUCCEEDED` with **no warnings**. Simulator work needs the
sandbox disabled; sandboxed `simctl` calls make SwiftData fail with
"Sandbox access to file-write-create denied".

## Verifying

There is no test target yet. The pure logic — payload builder, parser, link checker,
exporter, generator — compiles standalone, so verify it by building a throwaway
executable in the scratchpad:

```bash
swiftc -O -o /tmp/t Kodo/Models/QRType.swift Kodo/Services/Creating/QRPayloadBuilder.swift main.swift
```

Round-trip anything you touch: generate a code and decode it with Vision, or build a
payload and parse it back. A styled QR that no longer scans is the failure mode that
matters. Never claim a UI change works without seeing it — screenshot the simulator.

## Project quirks

- The target uses a **file-system synchronized group**: new files are picked up with
  no `.xcodeproj` edit. Moving files between folders is free.
- Info.plist values live in build settings as `INFOPLIST_KEY_*`, not a plist file.
- Deployment target is iOS 26.4, iPhone and iPad only.
- Joining a scanned Wi-Fi network needs the **Hotspot Configuration** capability,
  which is deliberately not enabled — enabling it without the account entitlement
  breaks device signing. The button fails gracefully until then.
- The Simulator has no camera. Test scanning through "Scan from photo", or on device.

## Git

- Commits are authored by the repo owner. **Never add a Claude co-author trailer or
  mention Claude, Anthropic or AI assistance** in commit messages, code or docs.
- Subject line in the imperative, body explaining why when it is not obvious.
- The repo is public and MIT licensed.

## Privacy when publishing

The owner's History contains real personal data — phone number, email address, home
Wi-Fi SSID. **Never put a raw History screenshot in the README or anywhere public.**
Filter to Websites first, or use a screen without personal entries.

## Known gaps

- No test target.
- The app icon is still the Xcode placeholder.
