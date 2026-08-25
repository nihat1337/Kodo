//
//  QRPayloadBuilder.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

struct QRPayloadBuilder {

    func payload(for type: QRType, input: QRInput) -> String? {
        switch type {
        case .website:
            return link(from: input.website)
        case .contact:
            return contact(input)
        case .wifi:
            return wifi(input)
        case .email:
            return email(input)
        case .sms:
            return sms(input)
        case .location:
            return location(input)
        }
    }

    private func link(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") { return trimmed }
        return "https://" + trimmed
    }

    private func contact(_ input: QRInput) -> String? {
        let name = clean(input.contactName)
        let phone = clean(input.contactPhone)
        let mail = clean(input.contactEmail)
        let organization = clean(input.contactOrganization)
        guard !name.isEmpty || !phone.isEmpty else { return nil }

        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        if !name.isEmpty { lines.append("FN:\(vCardEscaped(name))") }
        if !organization.isEmpty { lines.append("ORG:\(vCardEscaped(organization))") }
        if !phone.isEmpty { lines.append("TEL;TYPE=CELL:\(vCardEscaped(phone))") }
        if !mail.isEmpty { lines.append("EMAIL:\(vCardEscaped(mail))") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\n")
    }

    private func wifi(_ input: QRInput) -> String? {
        let ssid = clean(input.wifiSSID)
        guard !ssid.isEmpty else { return nil }

        var payload = "WIFI:T:\(input.wifiSecurity.rawValue);S:\(wifiEscaped(ssid));"
        if input.wifiSecurity != .open {
            payload += "P:\(wifiEscaped(input.wifiPassword));"
        }
        if input.wifiHidden {
            payload += "H:true;"
        }
        return payload + ";"
    }

    private func email(_ input: QRInput) -> String? {
        let address = clean(input.emailAddress)
        guard !address.isEmpty else { return nil }

        var query: [String] = []
        let subject = clean(input.emailSubject)
        let body = clean(input.emailBody)
        if !subject.isEmpty { query.append("subject=\(percentEncoded(subject))") }
        if !body.isEmpty { query.append("body=\(percentEncoded(body))") }

        let base = "mailto:\(address)"
        return query.isEmpty ? base : base + "?" + query.joined(separator: "&")
    }

    private func sms(_ input: QRInput) -> String? {
        let number = clean(input.smsNumber)
        guard !number.isEmpty else { return nil }

        let message = clean(input.smsMessage)
        return message.isEmpty ? "SMSTO:\(number):" : "SMSTO:\(number):\(message)"
    }

    private func location(_ input: QRInput) -> String? {
        guard let latitude = Double(clean(input.latitude)),
              let longitude = Double(clean(input.longitude)),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return "geo:\(latitude),\(longitude)"
    }

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wifiEscaped(_ text: String) -> String {
        var result = ""
        for character in text {
            if "\\;,:\"".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    private func vCardEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func percentEncoded(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}
