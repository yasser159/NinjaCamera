@preconcurrency import AVFoundation
import Foundation

final class CameraCaptureService: NSObject {
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let metadataOutput = AVCaptureMetadataOutput()

    private let sessionQueue = DispatchQueue(label: "ninjacamera.capture.session")
    private let metadataQueue = DispatchQueue(label: "ninjacamera.capture.metadata")
    private let diagnostics: DiagnosticsStore

    var onConfigured: ((Bool, String?) -> Void)?
    var onPhotoCapture: ((Result<Data, Error>) -> Void)?
    var onFacePresenceChanged: ((Bool) -> Void)?

    private(set) var isConfigured = false
    private var faceDetectionEnabled = false

    init(diagnostics: DiagnosticsStore) {
        self.diagnostics = diagnostics
        super.init()
    }

    func configureIfNeeded(completion: (() -> Void)? = nil) {
        guard !isConfigured else {
            completion?()
            return
        }

        diagnostics.log(subsystem: "camera", message: "Configuring capture session")
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            self.session.sessionPreset = .photo

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                Task { @MainActor in
                    self.diagnostics.error(subsystem: "camera", message: "No back camera available")
                    self.onConfigured?(false, "No back ping sensor available")
                }
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                guard self.session.canAddInput(videoInput) else {
                    Task { @MainActor in
                        self.diagnostics.error(subsystem: "camera", message: "Unable to add camera input")
                        self.onConfigured?(false, "Unable to add eye input")
                    }
                    return
                }

                self.session.addInput(videoInput)

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                }

                self.metadataOutput.setMetadataObjectsDelegate(self, queue: self.metadataQueue)
                self.metadataOutput.metadataObjectTypes = []

                if #available(iOS 16.0, *),
                   let maxDimensions = videoDevice.activeFormat.supportedMaxPhotoDimensions.last {
                    self.photoOutput.maxPhotoDimensions = maxDimensions
                }

                Task { @MainActor in
                    self.isConfigured = true
                    self.diagnostics.log(subsystem: "camera", message: "Capture session configured")
                    self.onConfigured?(true, nil)
                    completion?()
                }
            } catch {
                Task { @MainActor in
                    self.diagnostics.error(subsystem: "camera", message: "Capture configuration failed", metadata: [
                        "error": error.localizedDescription
                    ])
                    self.onConfigured?(false, "Eye configuration failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func startSession() {
        configureIfNeeded {
            self.sessionQueue.async {
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                Task { @MainActor in
                    self.diagnostics.log(subsystem: "camera", message: "Capture session started")
                }
                if self.faceDetectionEnabled {
                    self.configureFaceMetadataTypes()
                }
            }
        }
    }

    func stopSession(reason: String = "manual") {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.diagnostics.log(subsystem: "camera", message: "Capture session stopped", metadata: [
                    "reason": reason
                ])
            }
        }
    }

    func setFaceDetectionEnabled(_ enabled: Bool) {
        faceDetectionEnabled = enabled
        sessionQueue.async {
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            if enabled, self.metadataOutput.availableMetadataObjectTypes.contains(.face) {
                self.metadataOutput.metadataObjectTypes = [.face]
            } else {
                self.metadataOutput.metadataObjectTypes = []
            }

            Task { @MainActor in
                self.diagnostics.log(subsystem: "camera", message: "Face detection updated", metadata: [
                    "enabled": String(enabled)
                ])
            }
        }
    }

    func capturePhoto() {
        guard isConfigured else { return }
        sessionQueue.async {
            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }

            if #available(iOS 16.0, *) {
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            }

            Task { @MainActor in
                self.diagnostics.log(subsystem: "camera", message: "Capturing photo")
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func isSessionRunning() -> Bool {
        session.isRunning
    }

    private func configureFaceMetadataTypes(retryCount: Int = 0) {
        if metadataOutput.availableMetadataObjectTypes.contains(.face) {
            metadataOutput.metadataObjectTypes = [.face]
            return
        }

        if retryCount < 5 {
            sessionQueue.asyncAfter(deadline: .now() + 0.3) {
                self.configureFaceMetadataTypes(retryCount: retryCount + 1)
            }
        }
    }
}

extension CameraCaptureService: AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in
                self.diagnostics.error(subsystem: "camera", message: "Photo capture failed", metadata: [
                    "error": error.localizedDescription
                ])
                self.onPhotoCapture?(.failure(error))
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor in
                let failure = NSError(domain: "CameraCaptureService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Ping data unavailable"
                ])
                self.diagnostics.error(subsystem: "camera", message: "Photo data unavailable")
                self.onPhotoCapture?(.failure(failure))
            }
            return
        }

        Task { @MainActor in
            self.diagnostics.log(subsystem: "camera", message: "Photo capture completed", metadata: [
                "bytes": String(data.count)
            ])
            self.onPhotoCapture?(.success(data))
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let hasFace = metadataObjects.contains(where: { $0 is AVMetadataFaceObject })
        Task { @MainActor in
            self.onFacePresenceChanged?(hasFace)
        }
    }
}
