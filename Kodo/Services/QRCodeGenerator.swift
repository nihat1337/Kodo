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

    func makeImage(from text: String,
                   style: QRStyle = QRStyle(),
                   logo: CGImage? = nil,
                   minimumSize: CGFloat = 1024) -> CGImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        // A logo hides part of the code, so it only stays readable at the highest correction level.
        filter.correctionLevel = logo == nil ? style.correction.rawValue : QRCorrection.high.rawValue

        guard let output = filter.outputImage,
              output.extent.width > 0,
              let modules = modules(from: output) else { return nil }

        return draw(modules, style: style, logo: logo, minimumSize: minimumSize)
    }

    // MARK: - Reading the code

    /// The filter draws one pixel per module, so the raw output *is* the module grid.
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

    // MARK: - Drawing the code

    private func draw(_ modules: [[Bool]],
                      style: QRStyle,
                      logo: CGImage?,
                      minimumSize: CGFloat) -> CGImage? {
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

        canvas.setFillColor(cgColor(style.background))
        canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
        canvas.setFillColor(cgColor(style.foreground))

        let finders = finderRegions(in: modules)

        for row in 0..<rows {
            for column in 0..<columns where modules[row][column] {
                // The grid is read top down; the canvas draws bottom up.
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

        return canvas.makeImage()
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

    // MARK: - Finder patterns

    /// The three big corner squares are what a scanner looks for first, so they stay solid
    /// even when the rest of the code is drawn as dots.
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

    // MARK: - Export

    private func cgColor(_ color: CodeColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
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
