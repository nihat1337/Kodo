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

    var onCodeFound: ((String) -> Void)?
    var onFrame: ((CGImage) -> Void)?

    private let session = AVCaptureSession()
    private let context = CIContext()
    private let sessionQueue = DispatchQueue(label: "kodo.camera.session")
    private let outputQueue = DispatchQueue(label: "kodo.camera.output")
    private var device: AVCaptureDevice?
    private var isConfigured = false

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
        metadataOutput.metadataObjectTypes = [.qr]

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

        DispatchQueue.main.async {
            self.onCodeFound?(value)
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
