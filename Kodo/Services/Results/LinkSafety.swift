//
//  LinkSafety.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

struct LinkWarning: Identifiable, Equatable {
    let id: String
    let icon: String
    let message: String
}

struct LinkSafety {

    private static let shorteners: Set<String> = [
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly",
        "rebrand.ly", "cutt.ly", "shorturl.at", "rb.gy", "t.ly", "lnkd.in",
        "s.id", "tiny.cc", "shorte.st", "adf.ly", "bit.do", "soo.gd"
    ]

    func host(of url: URL) -> String {
        url.host(percentEncoded: false) ?? url.absoluteString
    }

    func warnings(for url: URL) -> [LinkWarning] {
        var found: [LinkWarning] = []
        let scheme = (url.scheme ?? "").lowercased()
        let host = self.host(of: url).lowercased()

        if url.user != nil || url.password != nil {
            found.append(LinkWarning(
                id: "userinfo",
                icon: "exclamationmark.triangle.fill",
                message: "The address hides its real destination before an @ sign. It actually opens \(host)."))
        }

        if host.contains("xn--") || host.unicodeScalars.contains(where: { !$0.isASCII }) {
            found.append(LinkWarning(
                id: "lookalike",
                icon: "exclamationmark.triangle.fill",
                message: "This domain uses special characters that can imitate a well known name. It really is \(host)."))
        }

        if isAddressLiteral(host) {
            found.append(LinkWarning(
                id: "ip",
                icon: "questionmark.circle.fill",
                message: "This link points straight at a numeric address instead of a named site."))
        }

        if Self.shorteners.contains(host) {
            found.append(LinkWarning(
                id: "shortener",
                icon: "eye.slash.fill",
                message: "This is a shortened link, so the real destination is hidden until you open it."))
        }

        if scheme == "http" {
            found.append(LinkWarning(
                id: "insecure",
                icon: "lock.open.fill",
                message: "This link is not encrypted. Anything you send on that page can be read on the way."))
        }

        if let port = url.port, port != 80, port != 443 {
            found.append(LinkWarning(
                id: "port",
                icon: "questionmark.circle.fill",
                message: "This link uses an unusual port (\(port))."))
        }

        return found
    }

    private func isAddressLiteral(_ host: String) -> Bool {
        if host.contains(":") { return true }

        let parts = host.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let number = Int(part) else { return false }
            return (0...255).contains(number)
        }
    }
}
