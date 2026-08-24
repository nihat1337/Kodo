//
//  CameraScanner.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import AVFoundation
import CoreImage

final class CameraScanner: NSObject,
                           AVCaptureMetadataOutputObjectsDelegate,
                           AVCaptureVideoDataOutputSampleBufferDelegate,
                           @unchecked Sendable {

    var onCodeFound: ((DetectedCode) -> Void)?
    var onFrame: ((CGImage) -> Void)?

    private let session = AVCaptureSession()
    private let context = CIContext()
    private let sessionQueue = DispatchQueue(label: "kodo.camera.session")
    private let outputQueue = DispatchQueue(label: "kodo.camera.output")
    private var device: AVCaptureDevice?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var isConfigured = false

    private static let wantedObjectTypes: [AVMetadataObject.ObjectType] = [
        .qr, .microQR, .aztec, .dataMatrix, .pdf417, .microPDF417,
        .ean8, .ean13, .upce, .code39, .code39Mod43, .code93, .code128,
        .itf14, .interleaved2of5, .codabar, .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited
    ]

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        self.device = device

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: outputQueue)
        self.metadataOutput = metadataOutput
        applyObjectTypes()

        let videoOutput = AVCaptureVideoDataOutput()
        guard session.canAddOutput(videoOutput) else { return }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        session.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        isConfigured = true
    }

    func start() {
        sessionQueue.async {
            self.configureIfNeeded()
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            self.setTorchOnSessionQueue(false)
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func applyObjectTypes() {
        guard let output = metadataOutput else { return }
        let supported = output.availableMetadataObjectTypes
        output.metadataObjectTypes = Self.wantedObjectTypes.filter { supported.contains($0) }
    }

    func setTorch(_ isOn: Bool) {
        sessionQueue.async {
            self.setTorchOnSessionQueue(isOn)
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async {
            guard let device = self.device else { return }
            guard (try? device.lockForConfiguration()) != nil else { return }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }

            device.unlockForConfiguration()
        }
    }

    private func setTorchOnSessionQueue(_ isOn: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = isOn ? .on : .off
        device.unlockForConfiguration()
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        let code = DetectedCode(value: value, symbology: Self.label(for: object.type))
        DispatchQueue.main.async {
            self.onCodeFound?(code)
        }
    }

    private static func label(for type: AVMetadataObject.ObjectType) -> String {
        switch type {
        case .qr: return "QR code"
        case .microQR: return "Micro QR"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        case .pdf417: return "PDF417"
        case .microPDF417: return "Micro PDF417"
        case .ean8: return "EAN-8"
        case .ean13: return "EAN-13"
        case .upce: return "UPC-E"
        case .code39: return "Code 39"
        case .code39Mod43: return "Code 39 mod 43"
        case .code93: return "Code 93"
        case .code128: return "Code 128"
        case .itf14: return "ITF-14"
        case .interleaved2of5: return "Interleaved 2 of 5"
        case .codabar: return "Codabar"
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: return "GS1 DataBar"
        default: return "Barcode"
        }
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: buffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        DispatchQueue.main.async {
            self.onFrame?(cgImage)
        }
    }
}
