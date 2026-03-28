import Combine
import Foundation

enum DiagnosticsLevel: String, CaseIterable, Codable {
    case info
    case warning
    case error
}

struct DiagnosticsEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: DiagnosticsLevel
    let subsystem: String
    let message: String
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        level: DiagnosticsLevel,
        subsystem: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.subsystem = subsystem
        self.message = message
        self.metadata = metadata
    }
}

@MainActor
final class DiagnosticsStore: ObservableObject {
    @Published private(set) var events: [DiagnosticsEvent] = []

    let maxEvents: Int
    private let formatter: ISO8601DateFormatter

    init(maxEvents: Int = 200) {
        self.maxEvents = max(1, maxEvents)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    func log(
        _ level: DiagnosticsLevel = .info,
        subsystem: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let event = DiagnosticsEvent(level: level, subsystem: subsystem, message: message, metadata: metadata)
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }

        let suffix: String
        if metadata.isEmpty {
            suffix = ""
        } else {
            suffix = " " + metadata
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
        }
        print("[diagnostics] \(formatter.string(from: event.timestamp)) [\(event.level.rawValue)] [\(event.subsystem)] \(event.message)\(suffix)")
    }

    func warning(subsystem: String, message: String, metadata: [String: String] = [:]) {
        log(.warning, subsystem: subsystem, message: message, metadata: metadata)
    }

    func error(subsystem: String, message: String, metadata: [String: String] = [:]) {
        log(.error, subsystem: subsystem, message: message, metadata: metadata)
    }

    func snapshot() -> [DiagnosticsEvent] {
        events
    }

    var shouldOfferQuickReport: Bool {
        let recent = events.suffix(25)
        let recentErrors = recent.filter { $0.level == .error }
        return recentErrors.count >= 3
    }
}
