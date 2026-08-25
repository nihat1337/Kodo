//
//  HistoryExporter.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

struct HistoryExporter {

    func plainText(_ records: [CodeRecord]) -> String {
        records.map(\.value).joined(separator: "\n")
    }

    func csv(_ records: [CodeRecord]) -> String {
        let header = "value,type,symbology,created,favourite"
        let formatter = ISO8601DateFormatter()
        let parser = ScannedContentParser()

        let rows = records.map { record in
            [
                quoted(record.value),
                quoted(parser.parse(record.value).title),
                quoted(record.symbology),
                quoted(formatter.string(from: record.createdAt)),
                record.isFavorite ? "yes" : "no"
            ].joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    func writeCSV(_ records: [CodeRecord]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Kodo codes.csv")
        do {
            try csv(records).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    func writeText(_ records: [CodeRecord]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Kodo codes.txt")
        do {
            try plainText(records).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
