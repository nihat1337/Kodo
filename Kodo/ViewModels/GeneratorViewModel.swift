//
//  GeneratorViewModel.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData
import Photos

@Observable
final class GeneratorViewModel {

    var text: String = ""
    private(set) var qrImage: Image?
    private(set) var shareURL: URL?
    private(set) var message: String?

    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored private let generator = QRCodeGenerator()
    @ObservationIgnored private var cgImage: CGImage?

    func generate() {
        message = nil

        guard let image = generator.makeImage(from: text) else {
            cgImage = nil
            qrImage = nil
            shareURL = nil
            return
        }

        cgImage = image
        qrImage = Image(decorative: image, scale: 1)
        shareURL = generator.writePNG(image, named: "QRCode")
        addToHistory()
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
        text = ""
        qrImage = nil
        shareURL = nil
        cgImage = nil
        message = nil
    }

    func load(_ record: CodeRecord) {
        text = record.value
        generate()
    }

    private func addToHistory() {
        guard let modelContext else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var descriptor = FetchDescriptor<CodeRecord>(
            predicate: #Predicate { $0.value == value },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }
        modelContext.insert(CodeRecord(value: value, kind: .created))
    }
}
