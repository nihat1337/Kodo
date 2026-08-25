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
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var toast: String?
    @State private var confirmDelete = false

    private let parser = ScannedContentParser()
    private let exporter = HistoryExporter()
    private let clipboard = Clipboard()
    private let generator = QRCodeGenerator()

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

    private var selectedRecords: [CodeRecord] {
        shown.filter { selection.contains($0.persistentModelID) }
    }

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        List(selection: $selection) {
            ForEach(shown) { record in
                NavigationLink {
                    CodeDetailView(record: record)
                } label: {
                    row(for: record)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(record)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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
        }
        .navigationTitle(isEditing ? selectionTitle : "History")
        .navigationBarTitleDisplayMode(isEditingTitleDisplayMode)
        .searchable(text: $searchText, prompt: "Search codes")
        .environment(\.editMode, $editMode)
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .alert(deleteAlertTitle, isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            selectButton
        }

        if isEditing {
            ToolbarItem(placement: .topBarTrailing) { deleteSelectedButton }
            ToolbarItem(placement: .topBarTrailing) { copySelectedButton }
            ToolbarItem(placement: .topBarTrailing) { shareSelectedButton }
        } else {
            ToolbarItem { filterMenu }
            ToolbarItem { favoritesToggle }
        }
    }

    private var selectButton: some View {
        Button(isEditing ? "Done" : "Select") {
            withAnimation {
                editMode = isEditing ? .inactive : .active
                selection.removeAll()
            }
        }
        .disabled(shown.isEmpty && !isEditing)
    }

    private var deleteSelectedButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(selection.isEmpty)
    }

    private var copySelectedButton: some View {
        Button {
            copySelected()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .disabled(selection.isEmpty)
    }

    private var shareSelectedButton: some View {
        Menu {
            ShareLink(item: sharedText) {
                Label("Share as text", systemImage: "text.alignleft")
            }

            if let file = exporter.writeText(selectedRecords) {
                ShareLink(item: file) {
                    Label("Export as text file", systemImage: "doc.text")
                }
            }

            if let file = exporter.writeCSV(selectedRecords) {
                ShareLink(item: file) {
                    Label("Export as CSV", systemImage: "tablecells")
                }
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(selection.isEmpty)
    }

    private var filterMenu: some View {
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
    }

    private var favoritesToggle: some View {
        Toggle(isOn: $favoritesOnly) {
            Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star")
        }
        .toggleStyle(.button)
    }

    private func deleteSelected() {
        let doomed = selectedRecords
        withAnimation {
            for record in doomed {
                modelContext.delete(record)
            }
            selection.removeAll()
        }
    }

    private func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if toast == message { toast = nil }
        }
    }

    private func copySelected() {
        let count = selection.count
        clipboard.copy(text: sharedText)
        finishSelecting()
        show(count == 1 ? "Code copied" : "\(count) codes copied")
    }

    private func finishSelecting() {
        withAnimation {
            selection.removeAll()
            editMode = .inactive
        }
    }

    private var deleteAlertTitle: String {
        selection.count == 1 ? "Delete this code?" : "Delete \(selection.count) codes?"
    }

    private var selectionTitle: String {
        selection.isEmpty ? "Select codes" : "\(selection.count) selected"
    }

    private var isEditingTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
        isEditing ? .inline : .large
    }

    private var sharedText: String {
        exporter.plainText(selectedRecords)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: CodeRecord.self, inMemory: true)
}
