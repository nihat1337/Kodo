//
//  SettingsKey.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Foundation

enum SettingsKey {
    static let scanSound = "settings.scanSound"
    static let scanHaptics = "settings.scanHaptics"
    static let showDetailsAutomatically = "settings.showDetailsAutomatically"
    static let saveHistory = "settings.saveHistory"

    /// Everything is on until the user says otherwise.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            scanSound: true,
            scanHaptics: true,
            showDetailsAutomatically: true,
            saveHistory: true
        ])
    }

    static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}
