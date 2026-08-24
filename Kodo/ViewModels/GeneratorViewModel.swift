//
//  GeneratorViewModel.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData
import Photos
import ImageIO

@Observable
final class GeneratorViewModel {

    var type: QRType = .website {
        didSet { clearResult() }
    }
    var input = QRInput()

    var style = QRStyle() {
        didSet { redrawIfNeeded() }
    }
    private(set) var hasLogo = false

    private(set) var qrImage: Image?
    private(set) var shareURL: URL?
    private(set) var message: String?

    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored private let generator = QRCodeGenerator()
    @ObservationIgnored private let builder = QRPayloadBuilder()
    @ObservationIgnored private var cgImage: CGImage?
    @ObservationIgnored private var logo: CGImage?

    var canGenerate: Bool {
        builder.payload(for: type, input: input) != nil
    }

    func generate() {
        message = nil

        guard let payload = builder.payload(for: type, input: input),
              let image = generator.makeImage(from: payload, style: style, logo: logo) else {
            clearResult()
            message = "Fill in the fields above first."
            return
        }

        cgImage = image
        qrImage = Image(decorative: image, scale: 1)
        shareURL = generator.writePNG(image, named: "QRCode")
        addToHistory(payload)
    }

    func saveToPhotos() async {
        guard let cgImage, let data = generator.pngData(from: cgImage) else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            message = "Photos access denied."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            message = "Saved to Photos."
        } catch {
            message = "Could not save the image."
        }
    }

    func clear() {
        // Clearing the result first stops the style reset below from redrawing anything.
        clearResult()
        input = QRInput()
        style = QRStyle()
        logo = nil
        hasLogo = false
    }

    func setLogo(_ data: Data?) {
        guard let data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }

        logo = image
        hasLogo = true
        redrawIfNeeded()
    }

    func removeLogo() {
        logo = nil
        hasLogo = false
        redrawIfNeeded()
    }

    /// Style changes repaint the code that is already on screen, without waiting for another tap.
    private func redrawIfNeeded() {
        guard qrImage != nil else { return }
        generate()
    }

    private func clearResult() {
        qrImage = nil
        shareURL = nil
        cgImage = nil
        message = nil
    }

    private func addToHistory(_ value: String) {
        guard let modelContext else { return }

        var descriptor = FetchDescriptor<CodeRecord>(
            predicate: #Predicate { $0.value == value },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }
        modelContext.insert(CodeRecord(value: value, kind: .created))
    }
}
