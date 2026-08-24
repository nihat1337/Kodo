//
//  ContentView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ScannerView()
            }
            .tabItem {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }

            NavigationStack {
                GeneratorView()
            }
            .tabItem {
                Label("Create", systemImage: "qrcode")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CodeRecord.self, inMemory: true)
}
