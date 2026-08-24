//
//  QRType.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

enum QRType: String, CaseIterable, Identifiable {
    case website
    case contact
    case wifi
    case email
    case sms
    case location

    var id: String { rawValue }

    var title: String {
        switch self {
        case .website: return "Website"
        case .contact: return "Contact"
        case .wifi: return "Wi-Fi"
        case .email: return "Email"
        case .sms: return "SMS"
        case .location: return "Location"
        }
    }

    var icon: String {
        switch self {
        case .website: return "globe"
        case .contact: return "person.crop.circle"
        case .wifi: return "wifi"
        case .email: return "envelope"
        case .sms: return "message"
        case .location: return "mappin.and.ellipse"
        }
    }
}

enum WiFiSecurity: String, CaseIterable, Identifiable {
    case wpa = "WPA"
    case wep = "WEP"
    case open = "nopass"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wpa: return "WPA/WPA2"
        case .wep: return "WEP"
        case .open: return "None"
        }
    }
}

struct QRInput {
    var website = ""

    var contactName = ""
    var contactPhone = ""
    var contactEmail = ""
    var contactOrganization = ""

    var wifiSSID = ""
    var wifiPassword = ""
    var wifiSecurity: WiFiSecurity = .wpa
    var wifiHidden = false

    var emailAddress = ""
    var emailSubject = ""
    var emailBody = ""

    var smsNumber = ""
    var smsMessage = ""

    var latitude = ""
    var longitude = ""
}
