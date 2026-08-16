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
    @State private var viewModel = ScannerViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var focusPoint: CGPoint?

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
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Scan from photo", systemImage: "photo")
            }

            if let scan = viewModel.lastScan {
                VStack(spacing: 12) {
                    Text(scan.value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .lineLimit(3)

                    if let url = scan.url {
                        Link("Open link", destination: url)
                            .buttonStyle(.borderedProminent)
                    }

                    Button("Scan again") {
                        viewModel.clearResult()
                    }
                }
            } else if let message = viewModel.message {
                Text(message)
                    .foregroundStyle(.secondary)
            } else {
                Text("Point the camera at a QR code")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Scan")
        .toolbar {
            Button {
                viewModel.toggleTorch()
            } label: {
                Label("Torch", systemImage: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash")
            }
        }
        .task {
            viewModel.modelContext = modelContext
            await viewModel.start()
        }
        .onDisappear { viewModel.stop() }
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
            placeholder("Camera access denied.\nEnable it in Settings.", icon: "camera.badge.ellipsis")

        case .unavailable:
            placeholder("No camera here.\nRun on a real device, or scan from a photo.", icon: "iphone.slash")
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
