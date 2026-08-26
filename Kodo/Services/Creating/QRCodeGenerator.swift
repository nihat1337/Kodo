//
//  QRCodeGenerator.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

struct QRCodeGenerator {

    private let context = CIContext()

    func makeImage(from text: String,
                   style: QRStyle = QRStyle(),
                   logo: CGImage? = nil,
                   minimumSize: CGFloat = 1024) -> CGImage? {
        guard let modules = extractModules(from: text, hasLogo: logo != nil, correction: style.correction) else { return nil }
        let rows = modules.count
        let columns = modules[0].count
        let scale = max(1, (minimumSize / CGFloat(columns)).rounded(.up))
        let width = Int(CGFloat(columns) * scale)
        let height = Int(CGFloat(rows) * scale)

        guard let canvas = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: 0,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        renderModules(modules, in: canvas, width: width, height: height, scale: scale, style: style, logo: logo)
        return canvas.makeImage()
    }

    func pdfData(from text: String,
                 style: QRStyle = QRStyle(),
                 logo: CGImage? = nil,
                 size: CGFloat = 1024) -> Data? {
        guard let modules = extractModules(from: text, hasLogo: logo != nil, correction: style.correction) else { return nil }
        let rows = modules.count
        let columns = modules[0].count
        let scale = size / CGFloat(columns)
        let width = Int(size)
        let height = Int(size)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }

        var mediaBox = CGRect(x: 0, y: 0, width: size, height: size)
        guard let canvas = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        canvas.beginPage(mediaBox: &mediaBox)
        renderModules(modules, in: canvas, width: width, height: height, scale: scale, style: style, logo: logo)
        canvas.endPage()
        canvas.closePDF()

        return data as Data
    }

    func writePDF(from text: String,
                  style: QRStyle = QRStyle(),
                  logo: CGImage? = nil,
                  named name: String = "QRCode") -> URL? {
        guard let data = pdfData(from: text, style: style, logo: logo) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    func svgString(from text: String,
                   style: QRStyle = QRStyle(),
                   logo: CGImage? = nil,
                   size: CGFloat = 1024) -> String? {
        guard let modules = extractModules(from: text, hasLogo: logo != nil, correction: style.correction) else { return nil }
        let rows = modules.count
        let columns = modules[0].count
        let scale = size / CGFloat(columns)
        let width = size
        let height = size

        let bgHex = hexColor(style.background)
        let fgHex = hexColor(style.foreground)
        let finders = finderRegions(in: modules)

        var elements: [String] = []

        for row in 0..<rows {
            for column in 0..<columns where modules[row][column] {
                let x = CGFloat(column) * scale
                let y = CGFloat(row) * scale
                let isFinder = finders.contains { $0.contains(row: row, column: column) }

                if isFinder {
                    elements.append("<rect x=\"\(x)\" y=\"\(y)\" width=\"\(scale)\" height=\"\(scale)\"/>")
                } else {
                    switch style.module {
                    case .square:
                        elements.append("<rect x=\"\(x)\" y=\"\(y)\" width=\"\(scale)\" height=\"\(scale)\"/>")
                    case .rounded:
                        let inset = scale * 0.04
                        let corner = scale * 0.3
                        elements.append("<rect x=\"\(x + inset)\" y=\"\(y + inset)\" width=\"\(scale - inset * 2)\" height=\"\(scale - inset * 2)\" rx=\"\(corner)\" ry=\"\(corner)\"/>")
                    case .dots:
                        let cx = x + scale / 2
                        let cy = y + scale / 2
                        let r = (scale / 2) - (scale * 0.06)
                        elements.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\"/>")
                    }
                }
            }
        }

        var logoSVG = ""
        if let logo, let logoData = pngData(from: logo) {
            let side = min(width, height) * 0.22
            let boxX = (width - side) / 2
            let boxY = (height - side) / 2
            let pad = side * 0.12
            let paddedX = boxX - pad
            let paddedY = boxY - pad
            let paddedSide = side + pad * 2
            let corner = paddedSide * 0.2

            let base64 = logoData.base64EncodedString()
            logoSVG = """
            <rect x=\"\(paddedX)\" y=\"\(paddedY)\" width=\"\(paddedSide)\" height=\"\(paddedSide)\" rx=\"\(corner)\" ry=\"\(corner)\" fill=\"\(bgHex)\"/>
            <image x=\"\(boxX)\" y=\"\(boxY)\" width=\"\(side)\" height=\"\(side)\" href=\"data:image/png;base64,\(base64)\" preserveAspectRatio=\"xMidYMid meet\"/>
            """
        }

        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(width) \(height)\" width=\"\(width)\" height=\"\(height)\">
        <rect width=\"100%\" height=\"100%\" fill=\"\(bgHex)\"/>
        <g fill=\"\(fgHex)\">
        \(elements.joined(separator: "\n"))
        </g>
        \(logoSVG)
        </svg>
        """
    }

    func svgData(from text: String,
                 style: QRStyle = QRStyle(),
                 logo: CGImage? = nil,
                 size: CGFloat = 1024) -> Data? {
        guard let string = svgString(from: text, style: style, logo: logo, size: size) else { return nil }
        return string.data(using: .utf8)
    }

    func writeSVG(from text: String,
                  style: QRStyle = QRStyle(),
                  logo: CGImage? = nil,
                  named name: String = "QRCode") -> URL? {
        guard let data = svgData(from: text, style: style, logo: logo) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).svg")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func extractModules(from text: String, hasLogo: Bool, correction: QRCorrection) -> [[Bool]]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.correctionLevel = hasLogo ? QRCorrection.high.rawValue : correction.rawValue

        guard let output = filter.outputImage,
              output.extent.width > 0 else { return nil }

        return modules(from: output)
    }

    private func modules(from image: CIImage) -> [[Bool]]? {
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        guard width > 0, height > 0,
              let cgImage = context.createCGImage(image, from: image.extent) else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let reader = CGContext(data: &pixels,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        reader.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return (0..<height).map { row in
            (0..<width).map { column in
                let offset = (row * width + column) * 4
                return pixels[offset] < 128
            }
        }
    }

    private func renderModules(_ modules: [[Bool]],
                              in canvas: CGContext,
                              width: Int,
                              height: Int,
                              scale: CGFloat,
                              style: QRStyle,
                              logo: CGImage?) {
        let rows = modules.count
        let columns = modules[0].count

        canvas.setFillColor(cgColor(style.background))
        canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
        canvas.setFillColor(cgColor(style.foreground))

        let finders = finderRegions(in: modules)

        for row in 0..<rows {
            for column in 0..<columns where modules[row][column] {
                let rect = CGRect(x: CGFloat(column) * scale,
                                  y: CGFloat(rows - row - 1) * scale,
                                  width: scale,
                                  height: scale)

                let isFinder = finders.contains { $0.contains(row: row, column: column) }
                if isFinder {
                    canvas.fill(rect)
                } else {
                    addShape(for: style.module, in: rect, to: canvas)
                }
            }
        }

        if let logo {
            drawLogo(logo, in: canvas, width: width, height: height, background: style.background)
        }
    }

    private func addShape(for module: QRModuleStyle, in rect: CGRect, to canvas: CGContext) {
        switch module {
        case .square:
            canvas.fill(rect)
        case .rounded:
            let path = CGPath(roundedRect: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04),
                              cornerWidth: rect.width * 0.3,
                              cornerHeight: rect.height * 0.3,
                              transform: nil)
            canvas.addPath(path)
            canvas.fillPath()
        case .dots:
            canvas.fillEllipse(in: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06))
        }
    }

    private func drawLogo(_ logo: CGImage,
                          in canvas: CGContext,
                          width: Int,
                          height: Int,
                          background: CodeColor) {
        let side = CGFloat(min(width, height)) * 0.22
        let box = CGRect(x: (CGFloat(width) - side) / 2,
                         y: (CGFloat(height) - side) / 2,
                         width: side,
                         height: side)
        let padded = box.insetBy(dx: -side * 0.12, dy: -side * 0.12)

        canvas.setFillColor(cgColor(background))
        canvas.addPath(CGPath(roundedRect: padded,
                              cornerWidth: padded.width * 0.2,
                              cornerHeight: padded.height * 0.2,
                              transform: nil))
        canvas.fillPath()

        canvas.saveGState()
        canvas.clip(to: [box])
        canvas.draw(logo, in: box)
        canvas.restoreGState()
    }

    private struct Region {
        let rows: Range<Int>
        let columns: Range<Int>

        func contains(row: Int, column: Int) -> Bool {
            rows.contains(row) && columns.contains(column)
        }
    }

    private func finderRegions(in modules: [[Bool]]) -> [Region] {
        var minRow = modules.count, maxRow = 0, minColumn = modules[0].count, maxColumn = 0

        for (rowIndex, row) in modules.enumerated() {
            for (columnIndex, isDark) in row.enumerated() where isDark {
                minRow = min(minRow, rowIndex)
                maxRow = max(maxRow, rowIndex)
                minColumn = min(minColumn, columnIndex)
                maxColumn = max(maxColumn, columnIndex)
            }
        }
        guard minRow <= maxRow, minColumn <= maxColumn else { return [] }

        let size = 7
        return [
            Region(rows: minRow..<(minRow + size), columns: minColumn..<(minColumn + size)),
            Region(rows: minRow..<(minRow + size), columns: (maxColumn - size + 1)..<(maxColumn + 1)),
            Region(rows: (maxRow - size + 1)..<(maxRow + 1), columns: minColumn..<(minColumn + size))
        ]
    }

    private func cgColor(_ color: CodeColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
    }

    private func hexColor(_ color: CodeColor) -> String {
        let r = Int((color.red * 255).rounded())
        let g = Int((color.green * 255).rounded())
        let b = Int((color.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
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
