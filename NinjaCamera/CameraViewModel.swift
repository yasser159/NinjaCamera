//
//  CameraViewModel.swift
//  NinjaCamera
//
//  Created by Codex on 1/18/26.
//

import AVFoundation
import AudioToolbox
import Combine
import Photos
import Speech
import SwiftUI
import UIKit

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    enum CaptureMode: String, CaseIterable, Identifiable {
        case photo = "Photo"
        case video = "Video"
        case timeLapse = "Time-lapse"
        case faceDetection = "Faces"
        case voice = "Now"

        var id: String { rawValue }
    }

    enum CaptureState: String {
        case idle = "Idle"
        case capturing = "Capturing"
        case recording = "Recording"
        case timeLapse = "Time-lapse"
        case error = "Error"
    }

    @Published var captureState: CaptureState = .idle
    @Published var statusMessage: String = "Ready"
    @Published var isVoiceEnabled = false
    @Published var isTimeLapseEnabled = false
    @Published var timeLapseInterval: Double = 15
    @Published var isDiscreetMode = false
    @Published var hapticsEnabled = true
    @Published var audioConfirmationEnabled = false
    @Published var lastError: String?
    @Published var isSessionConfigured = false
    @Published var isRecording = false
    @Published var timeLapseCountdown: Int = 0
    @Published var isFaceDetectionEnabled = false
    @Published var selectedMode: CaptureMode = .photo

    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let movieOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "ninjacamera.session.queue")
    private let metadataQueue = DispatchQueue(label: "ninjacamera.metadata.queue")
    private var timeLapseTimer: Timer?
    private var lastFaceCaptureDate: Date = .distantPast
    private let faceCaptureCooldown: TimeInterval = 3
    private var intervalMode: CaptureMode?
    private var isFacePresent = false

    private let audioEngine = AVAudioEngine()
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private var lastCommandTimestamp: Date = .distantPast

    private var originalBrightness: CGFloat?
    private var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configureSessionIfNeeded(completion: (() -> Void)? = nil) {
        guard !isSessionConfigured else {
            completion?()
            return
        }

        // Capture main-actor isolated state before hopping to the session queue
        let faceDetectionEnabledAtConfig = self.isFaceDetectionEnabled

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
                    self.fail("No back camera available")
                }
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                } else {
                    Task { @MainActor in self.fail("Unable to add camera input") }
                    return
                }

                if let audioDevice = AVCaptureDevice.default(for: .audio) {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                    }
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                if self.session.canAddOutput(self.movieOutput) {
                    self.session.addOutput(self.movieOutput)
                }

                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                }

                self.metadataOutput.setMetadataObjectsDelegate(self, queue: self.metadataQueue)
                if faceDetectionEnabledAtConfig,
                   self.metadataOutput.availableMetadataObjectTypes.contains(.face) {
                    self.metadataOutput.metadataObjectTypes = [.face]
                } else {
                    self.metadataOutput.metadataObjectTypes = []
                }

                // Prefer supported max photo dimensions (iOS 16+)
                if #available(iOS 16.0, *) {
                    if let maxDimensions = videoDevice.activeFormat.supportedMaxPhotoDimensions.last {
                        self.photoOutput.maxPhotoDimensions = maxDimensions
                    }
                }

                Task { @MainActor in
                    self.isSessionConfigured = true
                    completion?()
                }
            } catch {
                Task { @MainActor in
                    self.fail("Camera configuration failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func startSession() {
        requestCameraAccess { granted in
            guard granted else {
                self.fail("Camera permission is required")
                return
            }
            self.configureSessionIfNeeded {
                self.sessionQueue.async {
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        guard isSessionConfigured else { return }
        captureState = .capturing
        statusMessage = "Capturing photo"

        sessionQueue.async {
            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startRecording() {
        guard isSessionConfigured else { return }
        guard !movieOutput.isRecording else { return }

        requestMicrophoneAccess { granted in
            guard granted else {
                self.fail("Microphone permission is required for video")
                return
            }
            self.stopTimeLapse()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            Task { @MainActor in
                self.isRecording = true
                self.captureState = .recording
                self.statusMessage = "Recording video"
                self.emitConfirmation()
            }
        }
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    func startSelectedMode() {
        switch selectedMode {
        case .photo:
            capturePhoto()
        case .video:
            startRecording()
        case .timeLapse:
            if !isTimeLapseEnabled {
                isTimeLapseEnabled = true
                startTimeLapse()
            }
        case .faceDetection:
            if !isFaceDetectionEnabled {
                setFaceDetectionEnabled(true)
            }
        case .voice:
            if !isVoiceEnabled {
                setVoiceEnabled(true)
            }
        }
    }

    func stopSelectedMode() {
        switch selectedMode {
        case .photo:
            break
        case .video:
            stopRecording()
        case .timeLapse:
            stopTimeLapse()
        case .faceDetection:
            setFaceDetectionEnabled(false)
        case .voice:
            setVoiceEnabled(false)
        }
    }

    func stopAllCaptureModes() {
        stopRecording()
        stopTimeLapse()
        setFaceDetectionEnabled(false)
        setVoiceEnabled(false)
    }

    func toggleTimeLapse(_ enabled: Bool) {
        if enabled {
            disableOtherModes(except: .timeLapse)
            isTimeLapseEnabled = true
            startTimeLapse()
        } else {
            stopTimeLapse()
        }
    }

    func startTimeLapse() {
        guard isSessionConfigured else { return }
        if isRecording {
            stopRecording()
        }
        captureState = .timeLapse
        statusMessage = "Time-lapse running"

        startIntervalCapture(mode: .timeLapse)
    }

    @objc private func handleTimeLapseTick() {
        if timeLapseCountdown <= 1 {
            let shouldCapture: Bool
            switch intervalMode {
            case .timeLapse:
                shouldCapture = true
            case .faceDetection:
                shouldCapture = isFacePresent
            default:
                shouldCapture = false
            }

            if shouldCapture {
                capturePhoto()
            }
            timeLapseCountdown = max(1, Int(timeLapseInterval.rounded()))
        } else {
            timeLapseCountdown -= 1
        }
    }

    func stopTimeLapse() {
        stopIntervalCapture()
        if isTimeLapseEnabled {
            isTimeLapseEnabled = false
        }
        if !isRecording {
            captureState = .idle
            statusMessage = "Ready"
        }
    }

    private func startIntervalCapture(mode: CaptureMode) {
        intervalMode = mode
        timeLapseTimer?.invalidate()
        timeLapseCountdown = max(1, Int(timeLapseInterval.rounded()))
        timeLapseTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(handleTimeLapseTick), userInfo: nil, repeats: true)
    }

    private func stopIntervalCapture() {
        intervalMode = nil
        timeLapseTimer?.invalidate()
        timeLapseTimer = nil
        timeLapseCountdown = 0
    }

    private func disableOtherModes(except mode: CaptureMode) {
        if isVoiceEnabled {
            isVoiceEnabled = false
            stopVoiceRecognition()
        }
        if mode != .timeLapse, isTimeLapseEnabled {
            stopTimeLapse()
        }
        if mode != .faceDetection, isFaceDetectionEnabled {
            isFaceDetectionEnabled = false
            updateFaceDetectionOutput(enabled: false)
        }
    }

    private func updateFaceDetectionOutput(enabled: Bool) {
        sessionQueue.async {
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            if !self.session.outputs.contains(self.metadataOutput),
               self.session.canAddOutput(self.metadataOutput) {
                self.session.addOutput(self.metadataOutput)
            }

            if enabled, self.metadataOutput.availableMetadataObjectTypes.contains(.face) {
                self.metadataOutput.metadataObjectTypes = [.face]
            } else {
                self.metadataOutput.metadataObjectTypes = []
            }
        }
    }

    func setDiscreetMode(_ enabled: Bool) {
        if enabled {
            if originalBrightness == nil {
                originalBrightness = activeScreen?.brightness
            }
            activeScreen?.brightness = 0.05
        } else if let original = originalBrightness {
            activeScreen?.brightness = original
            originalBrightness = nil
        }
        isDiscreetMode = enabled
    }

    func setVoiceEnabled(_ enabled: Bool) {
        if enabled {
            stopAllCaptureModes()
            isVoiceEnabled = true
            startVoiceRecognition()
        } else {
            stopVoiceRecognition()
        }
    }

    func setFaceDetectionEnabled(_ enabled: Bool) {
        if enabled {
            disableOtherModes(except: .faceDetection)
            isFaceDetectionEnabled = true
            statusMessage = "Face detection running"
            updateFaceDetectionOutput(enabled: true)
            startIntervalCapture(mode: .faceDetection)
        } else {
            isFaceDetectionEnabled = false
            updateFaceDetectionOutput(enabled: false)
            stopIntervalCapture()
        }
    }

    private func startVoiceRecognition() {
        requestSpeechAccess { granted in
            guard granted else {
                self.fail("Speech recognition permission is required")
                self.isVoiceEnabled = false
                return
            }

            self.stopVoiceRecognition()
            self.speechRequest = SFSpeechAudioBufferRecognitionRequest()
            if let recognizer = self.speechRecognizer, recognizer.supportsOnDeviceRecognition {
                self.speechRequest?.requiresOnDeviceRecognition = true
            }
            self.speechRequest?.shouldReportPartialResults = true

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .mixWithOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                self.fail("Audio session error: \(error.localizedDescription)")
                self.isVoiceEnabled = false
                return
            }

            guard self.speechRecognizer != nil else {
                self.fail("Speech recognizer unavailable")
                self.isVoiceEnabled = false
                return
            }

            let inputNode = self.audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.speechRequest?.append(buffer)
            }

            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
            } catch {
                self.fail("Unable to start audio engine: \(error.localizedDescription)")
                self.isVoiceEnabled = false
                return
            }

            self.speechTask = self.speechRecognizer?.recognitionTask(with: self.speechRequest!) { [weak self] result, error in
                guard let self else { return }
                if let error = error {
                    self.fail("Speech error: \(error.localizedDescription)")
                    return
                }
                guard let result else { return }
                let command = result.bestTranscription.formattedString.lowercased()
                self.handleVoiceCommand(command)
            }
        }
    }

    private func stopVoiceRecognition() {
        speechTask?.cancel()
        speechTask = nil
        speechRequest?.endAudio()
        speechRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        if isVoiceEnabled {
            isVoiceEnabled = false
        }
    }

    private func handleVoiceCommand(_ transcript: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTimestamp) > 0.8 else { return }

        if transcript.contains("now") {
            lastCommandTimestamp = now
            capturePhoto()
            emitConfirmation()
        } else if transcript.contains("video") {
            lastCommandTimestamp = now
            startRecording()
        } else if transcript.contains("stop") {
            lastCommandTimestamp = now
            stopRecording()
            stopTimeLapse()
        }
    }

    private func emitConfirmation() {
        if hapticsEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        if audioConfirmationEnabled {
            AudioServicesPlaySystemSound(1057)
        }
    }

    @objc private func appWillResignActive() {
        stopRecording()
        stopTimeLapse()
        stopVoiceRecognition()
        stopSession()
        if isVoiceEnabled {
            isVoiceEnabled = false
        }
        statusMessage = "Paused: app inactive"
    }

    @objc private func appDidBecomeActive() {
        statusMessage = "Ready"
        startSession()
    }

    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                completion(true)
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in completion(granted) }
                }
            default:
                completion(false)
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                completion(true)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in completion(granted) }
                }
            default:
                completion(false)
            }
        }
    }

    private func requestSpeechAccess(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                completion(status == .authorized)
            }
        }
    }

    private func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                Task { @MainActor in completion(newStatus == .authorized || newStatus == .limited) }
            }
        default:
            completion(false)
        }
    }

    private func fail(_ message: String) {
        lastError = message
        captureState = .error
        statusMessage = message
    }
}

nonisolated extension CameraViewModel: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureMetadataOutputObjectsDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in
                self.fail("Photo capture failed: \(error.localizedDescription)")
            }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor in
                self.fail("Photo data unavailable")
            }
            return
        }

        Task { @MainActor in
            self.requestPhotoLibraryAccess { granted in
                guard granted else {
                    self.fail("Photo library permission is required")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: data, options: nil)
                }, completionHandler: { success, error in
                    Task { @MainActor in
                        if let error {
                            self.fail("Save failed: \(error.localizedDescription)")
                        } else if success {
                            self.statusMessage = "Photo saved"
                            if self.isRecording {
                                self.captureState = .recording
                            } else if self.isTimeLapseEnabled {
                                self.captureState = .timeLapse
                            } else {
                                self.captureState = .idle
                            }
                            self.emitConfirmation()
                        }
                    }
                })
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false
        }

        if let error {
            Task { @MainActor in
                self.fail("Recording failed: \(error.localizedDescription)")
            }
            return
        }

        Task { @MainActor in
            self.requestPhotoLibraryAccess { granted in
                guard granted else {
                    self.fail("Photo library permission is required")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .video, fileURL: outputFileURL, options: nil)
                }, completionHandler: { success, error in
                    Task { @MainActor in
                        if let error {
                            self.fail("Save failed: \(error.localizedDescription)")
                        } else if success {
                            self.statusMessage = "Video saved"
                            self.captureState = .idle
                            self.emitConfirmation()
                        }
                    }
                })
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let hasFace = metadataObjects.contains(where: { $0 is AVMetadataFaceObject })
        Task { @MainActor in
            self.isFacePresent = hasFace
            if hasFace, self.isFaceDetectionEnabled {
                self.emitConfirmation()
            }
        }
    }
}
