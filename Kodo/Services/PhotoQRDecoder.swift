//
//  PhotoQRDecoder.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation
import Vision

struct PhotoQRDecoder {

    func decode(imageData: Data) async -> String? {
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]

        guard let observations = try? await request.perform(on: imageData) else { return nil }
        return observations.compactMap(\.payloadString).first
    }
}
