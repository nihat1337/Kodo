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
    @State private var typeFilter: TypeFilter = .all
    @State private var searchText = ""

    private let parser = ScannedContentParser()

    private enum TypeFilter: String, CaseIterable, Identifiable {
        case all, website, wifi, contact, email, sms, location, text

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All types"
            case .website: return "Websites"
            case .wifi: return "Wi-Fi"
            case .contact: return "Contacts"
            case .email: return "Email"
            case .sms: return "SMS"
            case .location: return "Locations"
            case .text: return "Text"
            }
        }

        func matches(_ content: ScannedContent) -> Bool {
            switch (self, content) {
            case (.all, _), (.website, .website), (.wifi, .wifi), (.contact, .contact),
                 (.email, .email), (.sms, .sms), (.location, .location), (.text, .text):
                return true
            default:
                return false
            }
        }
    }

    private var shown: [CodeRecord] {
        records.filter { record in
            if favoritesOnly && !record.isFavorite { return false }

            if !searchText.isEmpty,
               !record.value.localizedCaseInsensitiveContains(searchText),
               !record.symbology.localizedCaseInsensitiveContains(searchText) {
                return false
            }

            guard typeFilter != .all else { return true }
            return typeFilter.matches(parser.parse(record.value))
        }
    }

    var body: some View {
        List {
            ForEach(shown) { record in
                NavigationLink {
                    CodeDetailView(record: record)
                } label: {
                    row(for: record)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        record.isFavorite.toggle()
                    } label: {
                        Label(record.isFavorite ? "Unfavorite" : "Favorite",
                              systemImage: record.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("History")
        .searchable(text: $searchText, prompt: "Search codes")
        .toolbar {
            Menu {
                Picker("Type", selection: $typeFilter) {
                    ForEach(TypeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            } label: {
                Label("Filter", systemImage: typeFilter == .all
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }

            Toggle(isOn: $favoritesOnly) {
                Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star")
            }
            .toggleStyle(.button)
        }
        .overlay {
            if shown.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if favoritesOnly {
                    ContentUnavailableView("No favorites", systemImage: "star",
                                           description: Text("Swipe a row to the right to star it."))
                } else if typeFilter != .all {
                    ContentUnavailableView("No \(typeFilter.title.lowercased())", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("Nothing in your history matches this filter."))
                } else {
                    ContentUnavailableView("Nothing yet", systemImage: "clock",
                                           description: Text("Codes you scan or create show up here."))
                }
            }
        }
    }

    private func row(for record: CodeRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: parser.parse(record.value).icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.value)
                    .lineLimit(1)

                Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if record.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
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
