//
//  ScannerViewModel.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData
import PhotosUI

@Observable
final class ScannerViewModel {

    enum Status {
        case idle
        case scanning
        case denied
        case unavailable
    }

    private(set) var status: Status = .idle
    private(set) var previewFrame: Image?
    private(set) var previewAspect: CGFloat = 9.0 / 16.0
    private(set) var lastScan: CodeRecord?
    private(set) var message: String?
    private(set) var isTorchOn = false

    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored private let scanner = CameraScanner()
    @ObservationIgnored private let photoDecoder = PhotoQRDecoder()

    init() {
        scanner.onCodeFound = { [weak self] value in
            self?.handle(value)
        }
        scanner.onFrame = { [weak self] cgImage in
            self?.previewFrame = Image(decorative: cgImage, scale: 1)
            self?.previewAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        }
    }

    func start() async {
        guard await scanner.requestPermission() else {
            status = .denied
            return
        }
        #if targetEnvironment(simulator)
        status = .unavailable
        #else
        scanner.start()
        status = .scanning
        #endif
    }

    func stop() {
        scanner.stop()
        previewFrame = nil
        isTorchOn = false
        if status == .scanning { status = .idle }
    }

    func toggleTorch() {
        isTorchOn.toggle()
        scanner.setTorch(isTorchOn)
    }

    func focus(atTap point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0, previewAspect > 0 else { return }

        let scale = max(size.width / previewAspect, size.height)
        let filledWidth = previewAspect * scale
        let filledHeight = scale

        let x = (point.x + (filledWidth - size.width) / 2) / filledWidth
        let y = (point.y + (filledHeight - size.height) / 2) / filledHeight

        scanner.focus(at: CGPoint(x: y, y: 1 - x))
    }

    func scanPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        message = nil

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            message = "Could not read that image."
            return
        }
        guard let value = await photoDecoder.decode(imageData: data) else {
            message = "No QR code found in that image."
            return
        }

        lastScan = nil
        handle(value)
    }

    func clearResult() {
        lastScan = nil
        message = nil
    }

    private func handle(_ value: String) {
        guard lastScan?.value != value else { return }

        let record = CodeRecord(value: value, kind: .scanned)
        modelContext?.insert(record)
        lastScan = record
    }
}
