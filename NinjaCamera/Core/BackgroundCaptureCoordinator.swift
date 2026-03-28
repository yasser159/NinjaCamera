import AVFoundation
import AVKit
import Combine
import SwiftUI
import UIKit

@MainActor
final class BackgroundCaptureCoordinator: NSObject, ObservableObject {
    enum LifecycleState: String, CaseIterable {
        case foregroundActive
        case foregroundInactive
        case backgroundStarting
        case backgroundRunning
        case backgroundSuspended
        case recovering
    }

    @Published private(set) var lifecycleState: LifecycleState = .foregroundActive
    @Published private(set) var pictureInPictureState: String = "Idle"

    var onRecoveryRequested: (() -> Void)?
    var isCaptureSessionRunning: (() -> Bool)?
    var sessionProvider: (() -> AVCaptureSession?)?

    private let diagnostics: DiagnosticsStore
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private weak var sourceView: UIView?
    private var pipController: AVPictureInPictureController?
    private var retryTimer: Timer?

    init(diagnostics: DiagnosticsStore) {
        self.diagnostics = diagnostics
        super.init()
    }

    func attachSourceView(_ view: UIView) {
        sourceView = view
        configurePictureInPictureControllerIfNeeded()
    }

    func handleWillResignActive(allowBackgroundCapture: Bool) {
        lifecycleState = .foregroundInactive
        diagnostics.log(subsystem: "background", message: "App will resign active", metadata: [
            "captureActive": String(allowBackgroundCapture)
        ])

        guard allowBackgroundCapture else { return }
        lifecycleState = .backgroundStarting
        beginBackgroundTask(reason: "resign_active")
        startPictureInPictureIfPossible()
        startRetryLoop()
    }

    func handleDidEnterBackground(allowBackgroundCapture: Bool) {
        lifecycleState = allowBackgroundCapture ? .backgroundRunning : .backgroundSuspended
        diagnostics.log(subsystem: "background", message: "App entered background", metadata: [
            "captureActive": String(allowBackgroundCapture)
        ])
    }

    func handleWillEnterForeground() {
        diagnostics.log(subsystem: "background", message: "App will enter foreground")
    }

    func handleDidBecomeActive(allowBackgroundCapture: Bool) {
        lifecycleState = .foregroundActive
        diagnostics.log(subsystem: "background", message: "App became active", metadata: [
            "captureActive": String(allowBackgroundCapture)
        ])
        stopRetryLoop()
        endBackgroundTask()
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
    }

    private func beginBackgroundTask(reason: String) {
        endBackgroundTask()
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "ninjacamera.background") { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lifecycleState = .backgroundSuspended
                self.diagnostics.warning(subsystem: "background", message: "Background task expired", metadata: [
                    "reason": reason
                ])
                self.endBackgroundTask()
            }
        }

        diagnostics.log(subsystem: "background", message: "Background task started", metadata: [
            "reason": reason
        ])
    }

    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        diagnostics.log(subsystem: "background", message: "Background task ended")
        backgroundTaskIdentifier = .invalid
    }

    private func configurePictureInPictureControllerIfNeeded() {
        guard pipController == nil else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            diagnostics.warning(subsystem: "background", message: "PiP unsupported on this device")
            pictureInPictureState = "Unsupported"
            return
        }
        guard let sourceView else { return }

        if #available(iOS 15.0, *) {
            let contentViewController = AVPictureInPictureVideoCallViewController()
            let previewView = PreviewLayerView()
            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            previewView.frame = contentViewController.view.bounds
            previewView.previewLayer.videoGravity = .resizeAspectFill
            previewView.previewLayer.session = sessionProvider?()
            contentViewController.view.addSubview(previewView)

            let contentSource = AVPictureInPictureController.ContentSource(
                activeVideoCallSourceView: sourceView,
                contentViewController: contentViewController
            )
            let pipController = AVPictureInPictureController(contentSource: contentSource)
            pipController.canStartPictureInPictureAutomaticallyFromInline = true
            pipController.delegate = self
            self.pipController = pipController
            diagnostics.log(subsystem: "background", message: "PiP controller configured")
        } else {
            diagnostics.warning(subsystem: "background", message: "PiP unavailable on OS version")
            pictureInPictureState = "Unavailable"
        }
    }

    private func startPictureInPictureIfPossible() {
        configurePictureInPictureControllerIfNeeded()
        guard let pipController else { return }
        if pipController.isPictureInPictureActive {
            pictureInPictureState = "Active"
            return
        }

        diagnostics.log(subsystem: "background", message: "Attempting to start PiP")
        if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
        } else {
            diagnostics.warning(subsystem: "background", message: "PiP not currently possible")
            pictureInPictureState = "Not possible"
        }
    }

    private func startRetryLoop() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.attemptRecoveryIfNeeded()
            }
        }
        diagnostics.log(subsystem: "background", message: "Background recovery loop started")
    }

    private func stopRetryLoop() {
        retryTimer?.invalidate()
        retryTimer = nil
        diagnostics.log(subsystem: "background", message: "Background recovery loop stopped")
    }

    private func attemptRecoveryIfNeeded() {
        guard lifecycleState == .backgroundStarting || lifecycleState == .backgroundRunning || lifecycleState == .backgroundSuspended else {
            return
        }
        guard let isCaptureSessionRunning else { return }
        if isCaptureSessionRunning() {
            return
        }

        lifecycleState = .recovering
        diagnostics.warning(subsystem: "background", message: "Capture session missing in background, requesting recovery")
        onRecoveryRequested?()
        lifecycleState = .backgroundRunning
    }
}

@MainActor
extension BackgroundCaptureCoordinator: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pictureInPictureState = "Starting"
        diagnostics.log(subsystem: "background", message: "PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pictureInPictureState = "Active"
        diagnostics.log(subsystem: "background", message: "PiP started")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        pictureInPictureState = "Failed"
        diagnostics.warning(subsystem: "background", message: "PiP failed", metadata: [
            "error": error.localizedDescription
        ])
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pictureInPictureState = "Stopping"
        diagnostics.log(subsystem: "background", message: "PiP will stop")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pictureInPictureState = "Stopped"
        diagnostics.log(subsystem: "background", message: "PiP stopped")
    }
}

private final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct PictureInPictureSourceBridge: UIViewRepresentable {
    let onReady: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            onReady(view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            onReady(uiView)
        }
    }
}
