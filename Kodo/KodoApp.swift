//
//  KodoApp.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData

@main
struct KodoApp: App {

    init() {
        SettingsKey.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CodeRecord.self)
    }
}
