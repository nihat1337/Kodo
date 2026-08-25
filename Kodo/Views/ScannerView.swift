//
//  ScannerView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ScannerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var viewModel = ScannerViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var focusPoint: CGPoint?
    @State private var copyMessage: String?

    private let clipboard = Clipboard()
    private let generator = QRCodeGenerator()

    var body: some View {
        VStack(spacing: 16) {

            GeometryReader { proxy in
                cameraArea
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        viewModel.focus(atTap: location, in: proxy.size)
                        showFocusRing(at: location)
                    }
                    .overlay {
                        if let focusPoint {
                            Circle()
                                .stroke(.yellow, lineWidth: 2)
                                .frame(width: 64, height: 64)
                                .position(focusPoint)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        flashButton
                            .padding(12)
                    }
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Scan from photo", systemImage: "photo")
            }

            if let scan = viewModel.lastScan {
                VStack(spacing: 12) {
                    Text(scan.symbology)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(scan.value)
                        .font(.callout)
                        .lineLimit(2)

                    Button("View details") {
                        viewModel.isShowingDetails = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        copy(scan)
                    } label: {
                        Label(isQRCode(scan) ? "Copy QR code" : "Copy barcode",
                              systemImage: "doc.on.doc")
                    }

                    if let copyMessage {
                        Text(copyMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Scan again") {
                        viewModel.clearResult()
                    }
                }
            } else if let message = viewModel.message {
                Text(message)
                    .foregroundStyle(.secondary)
            } else if viewModel.status != .denied && viewModel.status != .unavailable {
                Text("Point the camera at a QR code or barcode")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Scan")
        .task {
            viewModel.modelContext = modelContext
            await viewModel.start()
        }
        .onDisappear { viewModel.stop() }
        .sensoryFeedback(.success, trigger: viewModel.scanCount)
        .onChange(of: viewModel.autoOpenURL) { _, url in
            guard let url else { return }
            openURL(url)
            viewModel.autoOpenHandled()
        }
        .sheet(isPresented: $viewModel.isShowingDetails, onDismiss: viewModel.detailsDismissed) {
            if let scan = viewModel.lastScan {
                NavigationStack {
                    CodeDetailView(record: scan)
                        .toolbar {
                            Button("Done") { viewModel.isShowingDetails = false }
                        }
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                await viewModel.scanPhoto(newItem)
                photoItem = nil
            }
        }
    }

    @ViewBuilder
    private var cameraArea: some View {
        switch viewModel.status {
        case .scanning:
            if let frame = viewModel.previewFrame {
                frame
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder("Starting camera…", icon: "camera")
            }

        case .idle:
            placeholder("Starting camera…", icon: "camera")

        case .denied:
            ZStack {
                Color.gray.opacity(0.2)
                VStack(spacing: 12) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Kodo cannot use the camera.\nYou can turn it on in Settings.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: "app-settings:") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

        case .unavailable:
            placeholder("No camera here.\nRun on a real device, or scan from a photo.", icon: "iphone.slash")
        }
    }

    private var flashButton: some View {
        Button {
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.title3)
                .foregroundStyle(viewModel.isTorchOn ? .yellow : .white)
                .padding(12)
                .background(.black.opacity(0.45), in: Circle())
        }
    }

    private func placeholder(_ message: String, icon: String) -> some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.largeTitle)
                Text(message)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func isQRCode(_ record: CodeRecord) -> Bool {
        record.symbology.lowercased().contains("qr")
    }

    private func copy(_ record: CodeRecord) {
        if isQRCode(record), let image = generator.makeImage(from: record.value) {
            clipboard.copy(image: image)
            show("QR code copied")
        } else {
            clipboard.copy(text: record.value)
            show("Barcode number copied")
        }
    }

    private func show(_ message: String) {
        copyMessage = message
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if copyMessage == message { copyMessage = nil }
        }
    }

    private func showFocusRing(at point: CGPoint) {
        focusPoint = point
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            if focusPoint == point { focusPoint = nil }
        }
    }
}

#Preview {
    NavigationStack {
        ScannerView()
    }
    .modelContainer(for: CodeRecord.self, inMemory: true)
}
