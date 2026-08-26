//
//  CodeDetailView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI

struct CodeDetailView: View {

    let record: CodeRecord

    @Environment(\.openURL) private var openURL
    @State private var showPassword = false
    @State private var qrImage: Image?
    @State private var qrBitmap: CGImage?
    @State private var confirmOpen = false
    @State private var actionMessage: String?
    @State private var isWorking = false

    private let safety = LinkSafety()
    private let clipboard = Clipboard()
    private let generator = QRCodeGenerator()

    private var content: ScannedContent {
        ScannedContentParser().parse(record.value)
    }

    var body: some View {
        List {
            Section {
                codePreview
            }

            Section {
                details
            } header: {
                header
            }

            Section("Actions") {
                actions
                copyButtons

                if let actionMessage {
                    Text(actionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if isQRCode {
                    Menu {
                        ShareLink(item: record.value) {
                            Label("Share text", systemImage: "text.alignleft")
                        }
                        if let qrBitmap, let png = generator.writePNG(qrBitmap, named: "QRCode") {
                            ShareLink(item: png) {
                                Label("PNG image", systemImage: "photo")
                            }
                        }
                        if let pdf = generator.writePDF(from: record.value, named: "QRCode") {
                            ShareLink(item: pdf) {
                                Label("PDF document", systemImage: "doc.text")
                            }
                        }
                        if let svg = generator.writeSVG(from: record.value, named: "QRCode") {
                            ShareLink(item: svg) {
                                Label("SVG vector", systemImage: "curlybraces")
                            }
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(item: record.value) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    record.isFavorite.toggle()
                } label: {
                    Label(record.isFavorite ? "Remove from favorites" : "Add to favorites",
                          systemImage: record.isFavorite ? "star.fill" : "star")
                }
            }
        }
        .navigationTitle(content.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { makeCode() }
    }

    @ViewBuilder
    private var codePreview: some View {
        VStack(spacing: 10) {
            if let qrImage {
                qrImage
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
            } else {
                ProgressView()
                    .frame(height: 220)
            }

            if record.symbology != "QR code" {
                Text("Scanned as \(record.symbology), shown here as a QR code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private func run(_ work: @escaping () async -> String) {
        isWorking = true
        actionMessage = nil

        Task {
            let result = await work()
            actionMessage = result
            isWorking = false
        }
    }

    private func makeCode() {
        guard qrImage == nil,
              let image = QRCodeGenerator().makeImage(from: record.value) else { return }
        qrBitmap = image
        qrImage = Image(decorative: image, scale: 1)
    }

    private var isQRCode: Bool {
        record.symbology.lowercased().contains("qr")
    }

    private var copyButtons: some View {
        Group {
            if isQRCode, let qrBitmap {
                Button {
                    clipboard.copy(image: qrBitmap)
                    actionMessage = "QR code image copied."
                } label: {
                    Label("Copy QR image", systemImage: "photo.on.rectangle")
                }
            }

            Button {
                clipboard.copy(text: record.value)
                actionMessage = isQRCode ? "Text copied." : "Barcode number copied."
            } label: {
                Label(isQRCode ? "Copy text" : "Copy number", systemImage: "doc.on.doc")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: content.icon)
            Text(record.symbology)
            Spacer()
            Text(record.createdAt, format: .dateTime.hour().minute())
        }
    }

    @ViewBuilder
    private var details: some View {
        switch content {
        case .website(let url):
            row("Domain", safety.host(of: url))
            row("Address", url.absoluteString)

            ForEach(safety.warnings(for: url)) { warning in
                Label {
                    Text(warning.message)
                        .font(.footnote)
                } icon: {
                    Image(systemName: warning.icon)
                        .foregroundStyle(.orange)
                }
            }

        case .wifi(let ssid, let password, let security, let isHidden):
            row("Network", ssid)
            if !password.isEmpty {
                HStack {
                    Text("Password")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(showPassword ? password : String(repeating: "•", count: max(password.count, 6)))
                        .textSelection(.enabled)
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye" : "eye.slash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            row("Security", security)
            if isHidden { row("Hidden", "Yes") }

        case .contact(let name, let phone, let email, let organization):
            if !name.isEmpty { row("Name", name) }
            if !organization.isEmpty { row("Company", organization) }
            if !phone.isEmpty { row("Phone", phone) }
            if !email.isEmpty { row("Email", email) }

        case .email(let address, let subject, let body):
            row("To", address)
            if !subject.isEmpty { row("Subject", subject) }
            if !body.isEmpty { row("Message", body) }

        case .sms(let number, let message):
            row("Number", number)
            if !message.isEmpty { row("Message", message) }

        case .location(let latitude, let longitude):
            row("Latitude", String(latitude))
            row("Longitude", String(longitude))

        case .text(let text):
            Text(text)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch content {
        case .website(let url):
            let warnings = safety.warnings(for: url)

            Button {
                if warnings.isEmpty {
                    openURL(url)
                } else {
                    confirmOpen = true
                }
            } label: {
                Label(warnings.isEmpty ? "Open link" : "Open link anyway",
                      systemImage: warnings.isEmpty ? "safari" : "exclamationmark.shield")
            }
            .foregroundStyle(warnings.isEmpty ? Color.accentColor : .orange)
            .confirmationDialog("Open \(safety.host(of: url))?",
                                isPresented: $confirmOpen,
                                titleVisibility: .visible) {
                Button("Open anyway", role: .destructive) { openURL(url) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(warnings.map(\.message).joined(separator: "\n\n"))
            }

        case .contact(let name, let phone, let email, let organization):
            Button {
                run { await ContactSaver().save(name: name,
                                                phone: phone,
                                                email: email,
                                                organization: organization) }
            } label: {
                Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus")
            }
            .disabled(isWorking)

            if let url = link("tel:", phone) {
                Link(destination: url) { Label("Call", systemImage: "phone") }
            }
            if let url = link("mailto:", email) {
                Link(destination: url) { Label("Send email", systemImage: "envelope") }
            }

        case .email(let address, _, _):
            if let url = URL(string: record.value) ?? link("mailto:", address) {
                Link(destination: url) { Label("Write email", systemImage: "envelope") }
            }

        case .sms(let number, _):
            if let url = link("sms:", number) {
                Link(destination: url) { Label("Send message", systemImage: "message") }
            }

        case .location(let latitude, let longitude):
            if let url = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)") {
                Link(destination: url) { Label("Open in Maps", systemImage: "map") }
            }

        case .wifi(let ssid, let password, let security, let isHidden):
            Button {
                run { await WiFiJoiner().join(ssid: ssid,
                                              password: password,
                                              security: security,
                                              isHidden: isHidden) }
            } label: {
                Label("Join network", systemImage: "wifi")
            }
            .disabled(isWorking)

        case .text:
            EmptyView()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func link(_ scheme: String, _ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.replacingOccurrences(of: " ", with: "")
        return URL(string: scheme + stripped)
    }
}

#Preview {
    CodeDetailView(record: CodeRecord(value: #"WIFI:T:WPA;S:Kodo Cafe;P:latte\;123;H:true;;"#,
                                      kind: .scanned))
}
