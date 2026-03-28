import Foundation

@MainActor
final class TimeLapseEngine {
    enum Mode: String {
        case timeLapse
        case faceDetection
    }

    private let diagnostics: DiagnosticsStore
    private var timer: Timer?
    private(set) var activeMode: Mode?
    private(set) var selectedInterval: Double
    private var onTick: (Int) -> Void
    private var onFire: (Mode) -> Void
    private var countdown: Int = 0

    init(
        diagnostics: DiagnosticsStore,
        selectedInterval: Double,
        onTick: @escaping (Int) -> Void,
        onFire: @escaping (Mode) -> Void
    ) {
        self.diagnostics = diagnostics
        self.selectedInterval = selectedInterval
        self.onTick = onTick
        self.onFire = onFire
    }

    func start(mode: Mode, interval: Double) {
        selectedInterval = interval
        activeMode = mode
        timer?.invalidate()
        countdown = max(1, Int(interval.rounded()))
        onTick(countdown)
        diagnostics.log(subsystem: "timelapse", message: "Interval engine started", metadata: [
            "mode": mode.rawValue,
            "interval": String(Int(interval.rounded()))
        ])
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func updateInterval(_ interval: Double) {
        selectedInterval = interval
        if let activeMode {
            diagnostics.log(subsystem: "timelapse", message: "Interval updated", metadata: [
                "mode": activeMode.rawValue,
                "interval": String(Int(interval.rounded()))
            ])
            start(mode: activeMode, interval: interval)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        countdown = 0
        onTick(0)
        if let activeMode {
            diagnostics.log(subsystem: "timelapse", message: "Interval engine stopped", metadata: [
                "mode": activeMode.rawValue
            ])
        }
        activeMode = nil
    }

    private func tick() {
        guard let activeMode else { return }
        if countdown <= 1 {
            diagnostics.log(subsystem: "timelapse", message: "Interval trigger fired", metadata: [
                "mode": activeMode.rawValue,
                "interval": String(Int(selectedInterval.rounded()))
            ])
            onFire(activeMode)
            countdown = max(1, Int(selectedInterval.rounded()))
        } else {
            countdown -= 1
        }
        onTick(countdown)
    }
}
