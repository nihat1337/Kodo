//
//  ScannedContentParser.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

struct ScannedContentParser {

    func parse(_ raw: String) -> ScannedContent {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = value.lowercased()

        if lowercased.hasPrefix("wifi:") {
            return wifi(value)
        }
        if lowercased.hasPrefix("begin:vcard") {
            return contact(value)
        }
        if lowercased.hasPrefix("mailto:") {
            return email(value)
        }
        if lowercased.hasPrefix("smsto:") || lowercased.hasPrefix("sms:") {
            return sms(value)
        }
        if lowercased.hasPrefix("geo:") {
            return location(value)
        }
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://"),
           let url = URL(string: value) {
            return .website(url)
        }
        return .text(value)
    }

    private func wifi(_ value: String) -> ScannedContent {
        let body = String(value.dropFirst("WIFI:".count))
        let fields = splitEscaped(body, separator: ";")

        var ssid = "", password = "", security = "", hidden = ""
        for field in fields {
            guard let colon = field.firstIndex(of: ":") else { continue }
            let key = String(field[field.startIndex..<colon]).uppercased()
            let fieldValue = unescapeWiFi(String(field[field.index(after: colon)...]))
            switch key {
            case "S": ssid = fieldValue
            case "P": password = fieldValue
            case "T": security = fieldValue
            case "H": hidden = fieldValue
            default: break
            }
        }

        let securityName: String
        switch security.uppercased() {
        case "WPA", "WPA2", "WPA3": securityName = "WPA/WPA2"
        case "WEP": securityName = "WEP"
        case "NOPASS", "": securityName = "Open"
        default: securityName = security
        }

        return .wifi(ssid: ssid,
                     password: password,
                     security: securityName,
                     isHidden: hidden.lowercased() == "true")
    }

    private func contact(_ value: String) -> ScannedContent {
        var name = "", phone = "", email = "", organization = ""

        for line in value.components(separatedBy: .newlines) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let rawKey = String(line[line.startIndex..<colon]).uppercased()
            let key = rawKey.components(separatedBy: ";").first ?? rawKey
            let lineValue = unescapeVCard(String(line[line.index(after: colon)...]))

            switch key {
            case "FN": name = lineValue
            case "N" where name.isEmpty:
                name = lineValue.components(separatedBy: ";")
                    .filter { !$0.isEmpty }
                    .reversed()
                    .joined(separator: " ")
            case "TEL" where phone.isEmpty: phone = lineValue
            case "EMAIL" where email.isEmpty: email = lineValue
            case "ORG": organization = lineValue
            default: break
            }
        }

        return .contact(name: name, phone: phone, email: email, organization: organization)
    }

    private func email(_ value: String) -> ScannedContent {
        guard let components = URLComponents(string: value) else {
            return .email(address: String(value.dropFirst("mailto:".count)), subject: "", body: "")
        }
        let items = components.queryItems ?? []
        return .email(address: components.path,
                      subject: items.first { $0.name == "subject" }?.value ?? "",
                      body: items.first { $0.name == "body" }?.value ?? "")
    }

    private func sms(_ value: String) -> ScannedContent {
        let prefix = value.lowercased().hasPrefix("smsto:") ? "SMSTO:" : "sms:"
        let body = String(value.dropFirst(prefix.count))

        guard let colon = body.firstIndex(of: ":") else {
            return .sms(number: body, message: "")
        }
        return .sms(number: String(body[body.startIndex..<colon]),
                    message: String(body[body.index(after: colon)...]))
    }

    private func location(_ value: String) -> ScannedContent {
        let body = String(value.dropFirst("geo:".count))
        let coordinates = body.components(separatedBy: "?").first ?? body
        let parts = coordinates.components(separatedBy: ",")

        guard parts.count >= 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]) else {
            return .text(value)
        }
        return .location(latitude: latitude, longitude: longitude)
    }

    private func splitEscaped(_ text: String, separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaped = false

        for character in text {
            if escaped {
                current.append("\\")
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == separator {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private func unescapeWiFi(_ text: String) -> String {
        var result = ""
        var escaped = false
        for character in text {
            if escaped {
                result.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    private func unescapeVCard(_ text: String) -> String {
        var result = ""
        var escaped = false

        for character in text {
            if escaped {
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}
