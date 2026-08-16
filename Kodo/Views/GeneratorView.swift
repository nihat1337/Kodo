//
//  GeneratorView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData

struct GeneratorView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GeneratorViewModel()

    var body: some View {
        VStack(spacing: 20) {

            TextField("https://example.com", text: $viewModel.text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .onSubmit { viewModel.generate() }

            Button("Create QR code") {
                viewModel.generate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let qrImage = viewModel.qrImage {
                qrImage
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)

                HStack(spacing: 16) {
                    if let shareURL = viewModel.shareURL {
                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        Task { await viewModel.saveToPhotos() }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }

                    Button("Clear") {
                        viewModel.clear()
                    }
                }

                if let message = viewModel.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView("No code yet",
                                       systemImage: "qrcode",
                                       description: Text("Type a link, then tap Create."))
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Create")
        .task { viewModel.modelContext = modelContext }
    }
}

#Preview {
    NavigationStack {
        GeneratorView()
    }
    .modelContainer(for: CodeRecord.self, inMemory: true)
}
