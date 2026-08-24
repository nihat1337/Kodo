//
//  ScannedContent.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

enum ScannedContent {
    case website(URL)
    case wifi(ssid: String, password: String, security: String, isHidden: Bool)
    case contact(name: String, phone: String, email: String, organization: String)
    case email(address: String, subject: String, body: String)
    case sms(number: String, message: String)
    case location(latitude: Double, longitude: Double)
    case text(String)

    var title: String {
        switch self {
        case .website: return "Website"
        case .wifi: return "Wi-Fi network"
        case .contact: return "Contact"
        case .email: return "Email"
        case .sms: return "SMS"
        case .location: return "Location"
        case .text: return "Text"
        }
    }

    var icon: String {
        switch self {
        case .website: return "globe"
        case .wifi: return "wifi"
        case .contact: return "person.crop.circle"
        case .email: return "envelope"
        case .sms: return "message"
        case .location: return "mappin.and.ellipse"
        case .text: return "text.alignleft"
        }
    }
}
