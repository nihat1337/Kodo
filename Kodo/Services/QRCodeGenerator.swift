//
//  QRCodeGenerator.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

struct QRCodeGenerator {

    private let context = CIContext()

    func makeImage(from text: String, minimumSize: CGFloat = 1024) -> CGImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage, output.extent.width > 0 else { return nil }

        let scale = max(1, (minimumSize / output.extent.width).rounded(.up))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaled, from: scaled.extent)
    }

    func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    func writePNG(_ image: CGImage, named name: String) -> URL? {
        guard let data = pngData(from: image) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
