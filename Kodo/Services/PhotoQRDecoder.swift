//
//  PhotoQRDecoder.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation
import Vision

struct PhotoQRDecoder {

    func decode(imageData: Data) async -> DetectedCode? {
        let request = DetectBarcodesRequest()

        guard let observations = try? await request.perform(on: imageData),
              let observation = observations.first(where: { $0.payloadString != nil }),
              let value = observation.payloadString else { return nil }

        return DetectedCode(value: value, symbology: label(for: observation.symbology))
    }

    private func label(for symbology: BarcodeSymbology) -> String {
        switch symbology {
        case .qr: return "QR code"
        case .microQR: return "Micro QR"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        case .pdf417: return "PDF417"
        case .microPDF417: return "Micro PDF417"
        case .ean8: return "EAN-8"
        case .ean13: return "EAN-13"
        case .upce: return "UPC-E"
        case .code39: return "Code 39"
        case .code93: return "Code 93"
        case .code128: return "Code 128"
        case .itf14: return "ITF-14"
        case .i2of5: return "Interleaved 2 of 5"
        case .codabar: return "Codabar"
        default: return "Barcode"
        }
    }
}
