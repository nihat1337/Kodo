//
//  QRStyle.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

struct CodeColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let black = CodeColor(red: 0, green: 0, blue: 0)
    static let white = CodeColor(red: 1, green: 1, blue: 1)

    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}

enum QRModuleStyle: String, CaseIterable, Identifiable {
    case square
    case rounded
    case dots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return "Square"
        case .rounded: return "Rounded"
        case .dots: return "Dots"
        }
    }
}

enum QRCorrection: String, CaseIterable, Identifiable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .quartile: return "High"
        case .high: return "Highest"
        }
    }

    var detail: String {
        switch self {
        case .low: return "Smallest code, least tolerant of damage."
        case .medium: return "A good balance for screens and print."
        case .quartile: return "Survives scratches and smudges."
        case .high: return "Densest code, needed when a logo covers the middle."
        }
    }
}

struct QRPalette: Identifiable, Equatable {
    let id: String
    let name: String
    let foreground: CodeColor
    let background: CodeColor

    static let classic = QRPalette(id: "classic", name: "Classic",
                                   foreground: .black, background: .white)
    static let midnight = QRPalette(id: "midnight", name: "Midnight",
                                    foreground: CodeColor(red: 0.96, green: 0.96, blue: 0.98),
                                    background: CodeColor(red: 0.07, green: 0.08, blue: 0.12))
    static let ocean = QRPalette(id: "ocean", name: "Ocean",
                                 foreground: CodeColor(red: 0.05, green: 0.24, blue: 0.55),
                                 background: CodeColor(red: 0.90, green: 0.95, blue: 1.00))
    static let forest = QRPalette(id: "forest", name: "Forest",
                                  foreground: CodeColor(red: 0.06, green: 0.34, blue: 0.20),
                                  background: CodeColor(red: 0.95, green: 0.97, blue: 0.90))
    static let sunset = QRPalette(id: "sunset", name: "Sunset",
                                  foreground: CodeColor(red: 0.63, green: 0.17, blue: 0.10),
                                  background: CodeColor(red: 1.00, green: 0.95, blue: 0.88))
    static let grape = QRPalette(id: "grape", name: "Grape",
                                 foreground: CodeColor(red: 0.33, green: 0.11, blue: 0.55),
                                 background: CodeColor(red: 0.97, green: 0.94, blue: 1.00))
    static let coffee = QRPalette(id: "coffee", name: "Coffee",
                                  foreground: CodeColor(red: 0.29, green: 0.17, blue: 0.09),
                                  background: CodeColor(red: 0.96, green: 0.92, blue: 0.85))
    static let mint = QRPalette(id: "mint", name: "Mint",
                                foreground: CodeColor(red: 0.02, green: 0.38, blue: 0.36),
                                background: CodeColor(red: 0.90, green: 0.98, blue: 0.95))

    static let all: [QRPalette] = [classic, midnight, ocean, forest, sunset, grape, coffee, mint]
}

struct QRStyle: Equatable {
    var palette: QRPalette = .classic
    var module: QRModuleStyle = .square
    var correction: QRCorrection = .medium

    var foreground: CodeColor { palette.foreground }
    var background: CodeColor { palette.background }

    var hasPoorContrast: Bool {
        abs(foreground.luminance - background.luminance) < 0.4
    }
}
