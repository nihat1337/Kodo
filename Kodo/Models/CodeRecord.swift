//
//  CodeRecord.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation
import SwiftData

enum CodeKind: String, Codable {
    case scanned
    case created
}

@Model
final class CodeRecord {

    var value: String = ""
    var kind: CodeKind = CodeKind.scanned
    var createdAt: Date = Date()
    var isFavorite: Bool = false
    var symbology: String = "QR code"

    init(value: String,
         kind: CodeKind,
         createdAt: Date = Date(),
         isFavorite: Bool = false,
         symbology: String = "QR code") {
        self.value = value
        self.kind = kind
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.symbology = symbology
    }

    var url: URL? {
        let lowercased = value.lowercased()
        guard lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") else { return nil }
        return URL(string: value)
    }
}
