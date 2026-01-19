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

    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "ninjacamera.session.queue")
    private var timeLapseTimer: Timer?

    private let audioEngine = AVAudioEngine()
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private var lastCommandTimestamp: Date = .distantPast

    private var originalBrightness: CGFloat?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            defer { self.session.commitConfiguration() }

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

                self.photoOutput.isHighResolutionCaptureEnabled = true

                Task { @MainActor in
                    self.isSessionConfigured = true
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
            self.configureSessionIfNeeded()
            self.sessionQueue.async {
                if !self.session.isRunning {
                    self.session.startRunning()
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
            settings.isHighResolutionPhotoEnabled = true
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

    func toggleTimeLapse(_ enabled: Bool) {
        isTimeLapseEnabled = enabled
        if enabled {
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

        timeLapseTimer?.invalidate()
        timeLapseTimer = Timer.scheduledTimer(withTimeInterval: timeLapseInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.capturePhoto()
            }
        }
    }

    func stopTimeLapse() {
        timeLapseTimer?.invalidate()
        timeLapseTimer = nil
        if isTimeLapseEnabled {
            isTimeLapseEnabled = false
        }
        if !isRecording {
            captureState = .idle
            statusMessage = "Ready"
        }
    }

    func setDiscreetMode(_ enabled: Bool) {
        if enabled {
            if originalBrightness == nil {
                originalBrightness = UIScreen.main.brightness
            }
            UIScreen.main.brightness = 0.05
        } else if let original = originalBrightness {
            UIScreen.main.brightness = original
            originalBrightness = nil
        }
        isDiscreetMode = enabled
    }

    func setVoiceEnabled(_ enabled: Bool) {
        isVoiceEnabled = enabled
        if enabled {
            startVoiceRecognition()
        } else {
            stopVoiceRecognition()
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

nonisolated extension CameraViewModel: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
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
}
