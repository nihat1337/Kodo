//
//  WiFiJoiner.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation
import NetworkExtension

struct WiFiJoiner {

    func join(ssid: String, password: String, security: String, isHidden: Bool) async -> String {
        guard !ssid.isEmpty else { return "This code has no network name." }

        let configuration: NEHotspotConfiguration
        switch security {
        case "Open":
            configuration = NEHotspotConfiguration(ssid: ssid)
        case "WEP":
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: true)
        default:
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        }
        configuration.hidden = isHidden
        configuration.joinOnce = false

        do {
            try await NEHotspotConfigurationManager.shared.apply(configuration)
            return "Joining \(ssid)…"
        } catch let error as NEHotspotConfigurationError {
            return message(for: error, ssid: ssid)
        } catch {
            return "Could not join: \(error.localizedDescription)"
        }
    }

    private func message(for error: NEHotspotConfigurationError, ssid: String) -> String {
        switch error {
        case .alreadyAssociated:
            return "Already connected to \(ssid)."
        case .userDenied:
            return "You declined the request to join."
        case .invalidWPAPassphrase, .invalidWEPPassphrase:
            return "The password in this code is not valid for that network."
        case .invalidSSID:
            return "The network name in this code is not valid."
        case .pending, .systemConfiguration, .internal, .unknown:
            return "iOS could not apply the network settings."
        default:
            return "Could not join \(ssid)."
        }
    }
}
