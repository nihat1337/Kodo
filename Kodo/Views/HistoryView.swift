//
//  HistoryView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CodeRecord.createdAt, order: .reverse) private var records: [CodeRecord]
    @State private var favoritesOnly = false

    private var shown: [CodeRecord] {
        favoritesOnly ? records.filter(\.isFavorite) : records
    }

    var body: some View {
        List {
            ForEach(shown) { record in
                row(for: record)
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("History")
        .toolbar {
            Toggle(isOn: $favoritesOnly) {
                Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star")
            }
            .toggleStyle(.button)
        }
        .overlay {
            if shown.isEmpty {
                ContentUnavailableView(favoritesOnly ? "No favorites" : "Nothing yet",
                                       systemImage: favoritesOnly ? "star" : "clock",
                                       description: Text("Codes you scan or create show up here."))
            }
        }
    }

    private func row(for record: CodeRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind == .scanned ? "qrcode.viewfinder" : "qrcode")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                if let url = record.url {
                    Link(record.value, destination: url)
                        .lineLimit(1)
                } else {
                    Text(record.value)
                        .lineLimit(1)
                }

                Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                record.isFavorite.toggle()
            } label: {
                Image(systemName: record.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(record.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(shown[index])
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: CodeRecord.self, inMemory: true)
}
