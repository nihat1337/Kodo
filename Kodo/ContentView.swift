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
                GeneratorView()
            }
            .tabItem {
                Label("Create", systemImage: "qrcode")
            }

            NavigationStack {
                ScannerView()
            }
            .tabItem {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CodeRecord.self, inMemory: true)
}
