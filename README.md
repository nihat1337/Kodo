# Kodo

A small QR code app for iOS: turn a link into a QR code, and read QR codes with the camera or from a photo.

Written in **pure SwiftUI** — no UIKit anywhere, not even a `UIViewRepresentable` bridge. The camera preview is drawn by SwiftUI itself from raw video frames.

## Features

- **Create** — type a link, get a QR code. Export is rendered at 1024px+ (not the on-screen size), so it stays sharp when printed.
- **Share / Save** — share the code as a real `QRCode.png` file, or save it straight to Photos.
- **Scan** — live camera scanning, with a torch toggle and tap-to-focus.
- **Scan from a photo** — pick a screenshot someone sent you and read the code out of it.
- **History** — every code you scan or create is stored locally with a timestamp, and can be starred as a favorite. Swipe to delete.

## Requirements

- Xcode 26.4
- iOS 26.4 (set in `IPHONEOS_DEPLOYMENT_TARGET`; every API used here exists since iOS 17, so you can lower it if you need older devices)
- A real device for scanning — the Simulator has no camera. Creating codes, history and photo scanning all work in the Simulator.

## Project structure

```
Kodo/
├── KodoApp.swift                    @main + the SwiftData container
├── ContentView.swift                the three tabs
├── Models/
│   └── CodeRecord.swift             @Model: value, kind, date, isFavorite
├── ViewModels/
│   ├── GeneratorViewModel.swift
│   └── ScannerViewModel.swift
├── Views/
│   ├── GeneratorView.swift
│   ├── ScannerView.swift
│   └── HistoryView.swift
└── Services/
    ├── QRCodeGenerator.swift        Core Image: text -> CGImage -> PNG
    ├── CameraScanner.swift          AVFoundation: session, torch, focus
    └── PhotoQRDecoder.swift         Vision: read a QR out of an image
```

MVVM, with one rule that keeps it honest:

> **Services** know nothing about SwiftUI. **Views** know nothing about AVFoundation or Core Image. The **ViewModel** is the only translator between them.

That is why `QRCodeGenerator` returns a `CGImage` rather than an `Image` — restyling a screen never touches a service.

## How it works

### Creating a code

`TextField` → `GeneratorViewModel.text` → `QRCodeGenerator`:

1. `CIFilter.qrCodeGenerator()` turns the text bytes into a tiny `CIImage` (roughly one pixel per QR square).
2. The image is scaled up until it is at least 1024px wide.
3. `CIContext.createCGImage` renders it to real pixels.
4. The view model wraps that in `Image(decorative:scale:)`; ImageIO writes the PNG used by Share and Save.

Every created code is inserted into SwiftData (duplicates of the same link are skipped).

### Scanning

`CameraScanner` runs one `AVCaptureSession` with **two** outputs:

```
                              .-> AVCaptureMetadataOutput  -> "I saw this QR text"
back camera -> DeviceInput -> |
                              '-> AVCaptureVideoDataOutput -> one CGImage per frame
```

Normally the preview is an `AVCaptureVideoPreviewLayer` inside a `UIView`. Since this project is SwiftUI-only, each frame is converted to a `CGImage` and handed to the view as an `Image` — so the "live preview" is just an image that changes ~30 times a second.

Because there is no preview layer to convert coordinates, `ScannerViewModel.focus(atTap:in:)` does it by hand: it undoes the `scaledToFill` crop, then rotates the tap into the camera's landscape space.

The camera starts in `.task` and stops in `.onDisappear`, so it never runs in the background.

### Scanning from a photo

`PhotosPicker` gives back image `Data`, which goes to `DetectBarcodesRequest` (Vision) limited to `.qr` symbologies. The result goes through the same code path as a camera scan, so it lands in history too.

### History

`CodeRecord` is a SwiftData `@Model`. Views read it with `@Query(sort: \CodeRecord.createdAt, order: .reverse)`; the view models write to it through a `ModelContext` the view hands them. No manual saving — SwiftData autosaves.

## Permissions

| Key | Why |
| --- | --- |
| `NSCameraUsageDescription` | live scanning |
| `NSPhotoLibraryAddUsageDescription` | saving a created code to Photos |

The photo picker needs no permission — it runs out of process.

## Known gaps

- **No Copy button.** The only clipboard API on iOS is `UIPasteboard`, which is UIKit. Copy is available inside the share sheet instead.
- **No PDF or SVG export** yet, for people printing posters and table tents.
