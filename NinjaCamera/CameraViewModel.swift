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
        case photo = "Pings"
        case timeLapse = "Time-lapse"
        case faceDetection = "Faces"
        case voice = "Now"

        var id: String { rawValue }
    }

    enum CaptureState: String {
        case idle = "Idle"
        case capturing = "Capturing"
        case timeLapse = "Time-lapse"
        case error = "Error"
    }

    enum BugReportSubmissionResult {
        case success(BugReportResponse)
        case failure(Error)
    }

    @Published var captureState: CaptureState = .idle
    @Published var statusMessage: String = "Ready"
    @Published var isVoiceEnabled = false
    @Published var isTimeLapseEnabled = false
    @Published var timeLapseInterval: Double {
        didSet {
            defaults.set(timeLapseInterval, forKey: Self.timeLapseIntervalDefaultsKey)
            diagnosticsStore.log(subsystem: "timelapse", message: "Selected interval changed", metadata: [
                "interval": String(Int(timeLapseInterval))
            ])
            timeLapseEngine.updateInterval(timeLapseInterval)
        }
    }
    @Published var isDiscreetMode = false
    @Published var hapticsEnabled = true
    @Published var audioConfirmationEnabled = false
    @Published var lastError: String?
    @Published var isSessionConfigured = false
    @Published var timeLapseCountdown: Int = 0
    @Published var isFaceDetectionEnabled = false
    @Published var photoCount: Int = 0
    @Published var selectedMode: CaptureMode = .timeLapse
    @Published var lastBugReportMessage = ""

    let diagnosticsStore: DiagnosticsStore
    let backgroundCoordinator: BackgroundCaptureCoordinator

    private let defaults: UserDefaults
    private let captureService: CameraCaptureService
    private let bugReportService: BugReportService
    private lazy var timeLapseEngine: TimeLapseEngine = makeTimeLapseEngine()

    private let audioEngine = AVAudioEngine()
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private var lastCommandTimestamp: Date = .distantPast
    private var isFacePresent = false
    private var originalBrightness: CGFloat?

    private var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
    }

    private static let timeLapseIntervalDefaultsKey = "timelapse.interval.seconds"

    override convenience init() {
        self.init(
            diagnosticsStore: DiagnosticsStore(),
            bugReportService: BugReportService(),
            defaults: .standard
        )
    }

    init(
        diagnosticsStore: DiagnosticsStore,
        bugReportService: BugReportService,
        defaults: UserDefaults = .standard
    ) {
        self.diagnosticsStore = diagnosticsStore
        self.bugReportService = bugReportService
        self.defaults = defaults
        let savedInterval = max(1, (defaults.object(forKey: Self.timeLapseIntervalDefaultsKey) as? Double ?? 2).rounded())
        self.timeLapseInterval = savedInterval
        self.captureService = CameraCaptureService(diagnostics: diagnosticsStore)
        self.backgroundCoordinator = BackgroundCaptureCoordinator(diagnostics: diagnosticsStore)

        super.init()
        configureServices()
        configureAmbientAudioSession()

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        diagnosticsStore.log(subsystem: "app", message: "CameraViewModel initialized", metadata: [
            "defaultInterval": String(Int(savedInterval.rounded()))
        ])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startSession() {
        configureAmbientAudioSession()
        requestCameraAccess { granted in
            guard granted else {
                self.fail("Eye permission is required")
                return
            }

            self.captureService.configureIfNeeded {
                self.captureService.startSession()
                if self.isFaceDetectionEnabled {
                    self.captureService.setFaceDetectionEnabled(true)
                }
            }
        }
    }

    func stopSession(reason: String = "manual") {
        guard !isBackgroundCaptureEligible else {
            diagnosticsStore.log(subsystem: "camera", message: "Stop session ignored while background capture is eligible", metadata: [
                "reason": reason
            ])
            return
        }
        captureService.stopSession(reason: reason)
    }

    func capturePhoto() {
        guard isSessionConfigured else {
            diagnosticsStore.warning(subsystem: "camera", message: "Capture ignored because session is not configured")
            return
        }
        captureState = .capturing
        statusMessage = "Capturing ping"
        emitConfirmation()
        captureService.capturePhoto()
    }

    func startSelectedMode() {
        switch selectedMode {
        case .photo:
            startSession()
            capturePhoto()
        case .timeLapse:
            if !isTimeLapseEnabled {
                photoCount = 0
                isTimeLapseEnabled = true
                startTimeLapse()
            }
        case .faceDetection:
            if !isFaceDetectionEnabled {
                photoCount = 0
                setFaceDetectionEnabled(true)
            }
        case .voice:
            if !isVoiceEnabled {
                photoCount = 0
                setVoiceEnabled(true)
            }
        }
    }

    func stopSelectedMode() {
        switch selectedMode {
        case .photo:
            break
        case .timeLapse:
            stopTimeLapse()
        case .faceDetection:
            setFaceDetectionEnabled(false)
        case .voice:
            setVoiceEnabled(false)
        }
    }

    func stopAllCaptureModes() {
        stopTimeLapse()
        setFaceDetectionEnabled(false)
        setVoiceEnabled(false)
    }

    func startTimeLapse() {
        startSession()
        isTimeLapseEnabled = true
        captureState = .timeLapse
        statusMessage = "Time-lapse running"
        timeLapseEngine.start(mode: .timeLapse, interval: timeLapseInterval)
    }

    func stopTimeLapse() {
        timeLapseEngine.stop()
        isTimeLapseEnabled = false
        captureState = .idle
        statusMessage = "Ready"
    }

    func setDiscreetMode(_ enabled: Bool) {
        if enabled {
            if originalBrightness == nil {
                originalBrightness = activeScreen?.brightness
            }
            activeScreen?.brightness = 0.05
        } else if let originalBrightness {
            activeScreen?.brightness = originalBrightness
            self.originalBrightness = nil
        }
        diagnosticsStore.log(subsystem: "ui", message: "Discreet mode changed", metadata: [
            "enabled": String(enabled)
        ])
        isDiscreetMode = enabled
    }

    func setVoiceEnabled(_ enabled: Bool) {
        if enabled {
            stopAllCaptureModes()
            isVoiceEnabled = true
            startVoiceRecognition()
        } else {
            stopVoiceRecognition(keepEnabled: false)
        }
    }

    func setFaceDetectionEnabled(_ enabled: Bool) {
        if enabled {
            if isTimeLapseEnabled {
                stopTimeLapse()
            }
            if isVoiceEnabled {
                stopVoiceRecognition(keepEnabled: false)
            }
            isFaceDetectionEnabled = true
            statusMessage = "Face detection running"
            startSession()
            captureService.setFaceDetectionEnabled(true)
            timeLapseEngine.start(mode: .faceDetection, interval: timeLapseInterval)
        } else {
            isFaceDetectionEnabled = false
            captureService.setFaceDetectionEnabled(false)
            timeLapseEngine.stop()
            statusMessage = "Ready"
        }
    }

    func attachPictureInPictureSourceView(_ view: UIView) {
        backgroundCoordinator.attachSourceView(view)
    }

    func submitBugReport(draft: BugReportDraft) async -> BugReportSubmissionResult {
        do {
            diagnosticsStore.log(subsystem: "bugs159", message: "Submitting bug report", metadata: [
                "severity": draft.severity.rawValue
            ])
            let response = try await bugReportService.submit(draft: draft, recentLogs: diagnosticsStore.snapshot())
            lastBugReportMessage = response.intake?.acknowledgement ?? "Bug reported."
            diagnosticsStore.log(subsystem: "bugs159", message: "Bug report submitted", metadata: [
                "state": response.intake?.state ?? "unknown"
            ])
            return .success(response)
        } catch {
            diagnosticsStore.error(subsystem: "bugs159", message: "Bug report submission failed", metadata: [
                "error": error.localizedDescription
            ])
            lastBugReportMessage = error.localizedDescription
            return .failure(error)
        }
    }

    private var isBackgroundCaptureEligible: Bool {
        isTimeLapseEnabled || isFaceDetectionEnabled
    }

    private func configureServices() {
        captureService.onConfigured = { [weak self] configured, error in
            guard let self else { return }
            self.isSessionConfigured = configured
            if let error {
                self.fail(error)
            }
        }

        captureService.onPhotoCapture = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.saveCapturedPhoto(data)
            case .failure(let error):
                self.fail(error.localizedDescription)
            }
        }

        captureService.onFacePresenceChanged = { [weak self] hasFace in
            guard let self else { return }
            self.isFacePresent = hasFace
            if hasFace, self.isFaceDetectionEnabled {
                self.emitConfirmation()
            }
        }

        backgroundCoordinator.sessionProvider = { [weak self] in
            self?.captureService.session
        }
        backgroundCoordinator.isCaptureSessionRunning = { [weak self] in
            self?.captureService.isSessionRunning() ?? false
        }
        backgroundCoordinator.onRecoveryRequested = { [weak self] in
            guard let self else { return }
            self.diagnosticsStore.warning(subsystem: "background", message: "Recovery requested for background capture")
            self.startSession()
        }
        timeLapseCountdown = 0
    }

    private func makeTimeLapseEngine() -> TimeLapseEngine {
        TimeLapseEngine(
            diagnostics: diagnosticsStore,
            selectedInterval: timeLapseInterval,
            onTick: { [weak self] countdown in
                self?.timeLapseCountdown = countdown
            },
            onFire: { [weak self] mode in
                guard let self else { return }
                switch mode {
                case .timeLapse:
                    self.capturePhoto()
                case .faceDetection:
                    if self.isFacePresent {
                        self.capturePhoto()
                    } else {
                        self.diagnosticsStore.log(subsystem: "timelapse", message: "Face capture skipped because no face is present")
                    }
                }
            }
        )
    }

    private func startVoiceRecognition() {
        requestSpeechAccess { granted in
            guard granted else {
                self.fail("Speech recognition permission is required")
                self.isVoiceEnabled = false
                return
            }

            self.stopVoiceRecognition(keepEnabled: true)
            self.speechRequest = SFSpeechAudioBufferRecognitionRequest()
            if let recognizer = self.speechRecognizer, recognizer.supportsOnDeviceRecognition {
                self.speechRequest?.requiresOnDeviceRecognition = true
            }
            self.speechRequest?.shouldReportPartialResults = true

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
                try audioSession.setPreferredSampleRate(44_100)
                try audioSession.setPreferredIOBufferDuration(0.02)
                try audioSession.setActive(true, options: [])
                self.diagnosticsStore.log(subsystem: "audio", message: "Audio session configured for voice mode", metadata: [
                    "category": "record"
                ])
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
            var recordingFormat = inputNode.outputFormat(forBus: 0)
            if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
                let sampleRate = audioSession.sampleRate > 0 ? audioSession.sampleRate : 44_100
                let channels = max(1, audioSession.inputNumberOfChannels)
                if let fallback = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: UInt32(channels)) {
                    recordingFormat = fallback
                } else {
                    self.fail("Audio input format unavailable")
                    self.isVoiceEnabled = false
                    return
                }
            }

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
                if let error {
                    if !self.isVoiceEnabled {
                        return
                    }
                    if self.shouldRestartSpeechRecognition(for: error) {
                        self.restartVoiceRecognition()
                        return
                    }
                    self.fail("Speech error: \(error.localizedDescription)")
                    return
                }
                guard let result else { return }
                let command = result.bestTranscription.formattedString.lowercased()
                self.handleVoiceCommand(command)
            }
        }
    }

    private func stopVoiceRecognition(keepEnabled: Bool = true) {
        speechTask?.cancel()
        speechTask = nil
        speechRequest?.endAudio()
        speechRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        configureAmbientAudioSession()
        if !keepEnabled {
            isVoiceEnabled = false
        }
    }

    private func shouldRestartSpeechRecognition(for error: Error) -> Bool {
        let description = (error as NSError).localizedDescription.lowercased()
        return description.contains("no speech")
    }

    private func restartVoiceRecognition() {
        stopVoiceRecognition(keepEnabled: true)
        guard isVoiceEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.isVoiceEnabled else { return }
            self.startVoiceRecognition()
        }
    }

    private func handleVoiceCommand(_ transcript: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTimestamp) > 0.8 else { return }

        if transcript.contains("now") {
            lastCommandTimestamp = now
            capturePhoto()
            emitConfirmation()
        } else if transcript.contains("stop") {
            lastCommandTimestamp = now
            stopTimeLapse()
        }
    }

    private func emitConfirmation() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        if audioConfirmationEnabled {
            AudioServicesPlaySystemSound(1057)
        }
    }

    @objc private func appWillResignActive() {
        diagnosticsStore.log(subsystem: "lifecycle", message: "Application will resign active")
        if isVoiceEnabled {
            stopVoiceRecognition(keepEnabled: false)
        }
        backgroundCoordinator.handleWillResignActive(allowBackgroundCapture: isBackgroundCaptureEligible)
        if !isBackgroundCaptureEligible {
            captureService.stopSession(reason: "app_will_resign_active")
            statusMessage = "Paused: app inactive"
        }
    }

    @objc private func appDidEnterBackground() {
        backgroundCoordinator.handleDidEnterBackground(allowBackgroundCapture: isBackgroundCaptureEligible)
    }

    @objc private func appWillEnterForeground() {
        backgroundCoordinator.handleWillEnterForeground()
    }

    @objc private func appDidBecomeActive() {
        backgroundCoordinator.handleDidBecomeActive(allowBackgroundCapture: isBackgroundCaptureEligible)
        statusMessage = isBackgroundCaptureEligible ? "Background capture recovered" : "Ready"
        configureAmbientAudioSession()
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

    private func saveCapturedPhoto(_ data: Data) {
        requestPhotoLibraryAccess { granted in
            guard granted else {
                self.fail("Pings library permission is required")
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
                        self.statusMessage = "Ping saved"
                        self.photoCount += 1
                        self.captureState = self.isTimeLapseEnabled || self.isFaceDetectionEnabled ? .timeLapse : .idle
                        self.emitConfirmation()
                        self.diagnosticsStore.log(subsystem: "camera", message: "Photo saved to library", metadata: [
                            "photoCount": String(self.photoCount)
                        ])
                    }
                }
            })
        }
    }

    private func fail(_ message: String) {
        lastError = message
        captureState = .error
        statusMessage = message
        diagnosticsStore.error(subsystem: "app", message: message)
    }

    private func configureAmbientAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: [])
            diagnosticsStore.log(subsystem: "audio", message: "Ambient audio session configured", metadata: [
                "category": "ambient"
            ])
        } catch {
            diagnosticsStore.warning(subsystem: "audio", message: "Failed to configure ambient audio session", metadata: [
                "error": error.localizedDescription
            ])
        }
    }
}
