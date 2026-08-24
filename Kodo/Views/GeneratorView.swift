//
//  GeneratorView.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct GeneratorView: View {

    private enum Field: Hashable {
        case website
        case contactName, contactPhone, contactEmail, contactOrganization
        case wifiSSID, wifiPasswordSecure, wifiPasswordPlain
        case emailAddress, emailSubject, emailBody
        case smsNumber, smsMessage
        case latitude, longitude
    }

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GeneratorViewModel()
    @State private var showPassword = false
    @State private var logoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]
    private let resultID = "qrResult"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {

                    typeButtons

                    VStack(alignment: .leading, spacing: 14) {
                        Text(viewModel.type.title)
                            .font(.headline)

                        fields
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    styleSection

                    Button {
                        focusedField = nil
                        viewModel.generate()
                        scrollToResult(using: proxy)
                    } label: {
                        Text("Create QR code")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canGenerate)

                    result
                        .id(resultID)
                }
                .padding()
                .animation(.snappy, value: viewModel.type)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Create")
        .task { viewModel.modelContext = modelContext }
        .onChange(of: viewModel.type) { _, _ in resetTyping() }
        .onChange(of: viewModel.input.wifiSecurity) { _, _ in resetTyping() }
        .onChange(of: logoItem) { _, newItem in
            Task {
                let data = try? await newItem?.loadTransferable(type: Data.self)
                viewModel.setLogo(data)
            }
        }
    }

    private var styleSection: some View {
        DisclosureGroup("Style") {
            VStack(alignment: .leading, spacing: 20) {

                styleGroup("Colour") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(QRPalette.all) { palette in
                                Button {
                                    viewModel.style.palette = palette
                                } label: {
                                    paletteSwatch(palette, isSelected: viewModel.style.palette == palette)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()
                }

                styleGroup("Shape") {
                    HStack(spacing: 12) {
                        ForEach(QRModuleStyle.allCases) { module in
                            Button {
                                viewModel.style.module = module
                            } label: {
                                shapeCard(module, isSelected: viewModel.style.module == module)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                styleGroup("Error correction") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(QRCorrection.allCases) { level in
                                Button {
                                    viewModel.style.correction = level
                                } label: {
                                    Text(level.title)
                                        .font(.caption.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(viewModel.style.correction == level
                                                    ? Color.accentColor : Color.gray.opacity(0.12),
                                                    in: Capsule())
                                        .foregroundStyle(viewModel.style.correction == level
                                                         ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .opacity(viewModel.hasLogo ? 0.4 : 1)
                        .disabled(viewModel.hasLogo)

                        Text(viewModel.hasLogo
                             ? "A logo needs the highest correction level, so it is fixed while one is set."
                             : viewModel.style.correction.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                styleGroup("Logo") {
                    HStack {
                        PhotosPicker(selection: $logoItem, matching: .images) {
                            Label(viewModel.hasLogo ? "Change logo" : "Add logo", systemImage: "photo.circle")
                        }

                        if viewModel.hasLogo {
                            Spacer()
                            Button("Remove", role: .destructive) {
                                viewModel.removeLogo()
                                logoItem = nil
                            }
                        }
                    }
                    .font(.callout)
                }
            }
            .padding(.top, 12)
        }
        .tint(.primary)
    }

    private func styleGroup<Content: View>(_ title: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func paletteSwatch(_ palette: QRPalette, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color(palette.background))
                Image(systemName: "qrcode")
                    .font(.title3)
                    .foregroundStyle(color(palette.foreground))
            }
            .frame(width: 54, height: 54)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2.5 : 1)
            }

            Text(palette.name)
                .font(.caption2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }

    private func shapeCard(_ module: QRModuleStyle, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            shapePreview(module)
            Text(module.title)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
    }

    /// A tiny nine module patch drawn in the shape it represents.
    private func shapePreview(_ module: QRModuleStyle) -> some View {
        let pattern = [[true, true, false], [true, false, true], [false, true, true]]

        return VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { column in
                        Group {
                            switch module {
                            case .square:
                                Rectangle()
                            case .rounded:
                                RoundedRectangle(cornerRadius: 2.5)
                            case .dots:
                                Circle()
                            }
                        }
                        .frame(width: 8, height: 8)
                        .opacity(pattern[row][column] ? 1 : 0)
                    }
                }
            }
        }
    }

    private func color(_ stored: CodeColor) -> Color {
        Color(red: stored.red, green: stored.green, blue: stored.blue)
    }

    private var typeButtons: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(QRType.allCases) { type in
                let isSelected = type == viewModel.type

                Button {
                    viewModel.type = type
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: type.icon)
                            .font(.title2)
                        Text(type.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    }
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch viewModel.type {
        case .website:
            labeled("Website address", $viewModel.input.website, field: .website)
                .keyboardType(.URL)

        case .contact:
            labeled("Name", $viewModel.input.contactName, field: .contactName)
            labeled("Phone", $viewModel.input.contactPhone, field: .contactPhone)
                .keyboardType(.phonePad)
            labeled("Email", $viewModel.input.contactEmail, field: .contactEmail)
                .keyboardType(.emailAddress)
            labeled("Company (optional)", $viewModel.input.contactOrganization, field: .contactOrganization)

        case .wifi:
            labeled("Network name (SSID)", $viewModel.input.wifiSSID, field: .wifiSSID)

            if viewModel.input.wifiSecurity != .open {
                passwordField
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Security")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Security", selection: $viewModel.input.wifiSecurity) {
                    ForEach(WiFiSecurity.allCases) { security in
                        Text(security.title).tag(security)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle("Hidden network", isOn: $viewModel.input.wifiHidden)

        case .email:
            labeled("Email address", $viewModel.input.emailAddress, field: .emailAddress)
                .keyboardType(.emailAddress)
            labeled("Subject (optional)", $viewModel.input.emailSubject, field: .emailSubject)
            labeled("Message (optional)", $viewModel.input.emailBody, field: .emailBody)

        case .sms:
            labeled("Phone number", $viewModel.input.smsNumber, field: .smsNumber)
                .keyboardType(.phonePad)
            labeled("Message (optional)", $viewModel.input.smsMessage, field: .smsMessage)

        case .location:
            labeled("Latitude", $viewModel.input.latitude, field: .latitude)
                .keyboardType(.numbersAndPunctuation)
            labeled("Longitude", $viewModel.input.longitude, field: .longitude)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ZStack {
                    SecureField("", text: $viewModel.input.wifiPassword)
                        .focused($focusedField, equals: .wifiPasswordSecure)
                        .opacity(showPassword ? 0 : 1)
                        .allowsHitTesting(!showPassword)

                    TextField("", text: $viewModel.input.wifiPassword)
                        .focused($focusedField, equals: .wifiPasswordPlain)
                        .opacity(showPassword ? 1 : 0)
                        .allowsHitTesting(showPassword)
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    let wasTyping = isTypingPassword
                    showPassword.toggle()
                    if wasTyping { focusedField = activePasswordField }
                } label: {
                    Image(systemName: showPassword ? "eye" : "eye.slash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = activePasswordField }
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.gray.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var result: some View {
        VStack(spacing: 20) {
            resultContent
        }
    }

    @ViewBuilder
    private var resultContent: some View {
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
        } else {
            ContentUnavailableView("No code yet",
                                   systemImage: "qrcode",
                                   description: Text("Fill in the fields, then tap Create."))
        }

        if let message = viewModel.message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func labeled(_ label: String,
                         _ text: Binding<String>,
                         field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
        }
    }

    private var activePasswordField: Field {
        showPassword ? .wifiPasswordPlain : .wifiPasswordSecure
    }

    private var isTypingPassword: Bool {
        focusedField == .wifiPasswordSecure || focusedField == .wifiPasswordPlain
    }

    private func resetTyping() {
        focusedField = nil
        showPassword = false
    }

    private func scrollToResult(using proxy: ScrollViewProxy) {
        guard viewModel.qrImage != nil else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.smooth(duration: 0.6)) {
                proxy.scrollTo(resultID, anchor: .center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GeneratorView()
    }
    .modelContainer(for: CodeRecord.self, inMemory: true)
}
