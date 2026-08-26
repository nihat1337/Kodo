//
//  ContentView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {

    @AppStorage(SettingsKey.hasSeenGuide) private var hasSeenGuide = false
    @State private var showGuide = false

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
        .task {
            if !hasSeenGuide {
                showGuide = true
                hasSeenGuide = true
            }
        }
        .sheet(isPresented: $showGuide) {
            GuideView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CodeRecord.self, inMemory: true)
}
