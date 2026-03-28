import Foundation

enum BugSeverity: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }
}

struct BugReportPayload: Encodable, Equatable {
    struct Metadata: Encodable, Equatable {
        let recentLogs: [DiagnosticsEvent]
    }

    let appId: String
    let appName: String
    let projectPath: String
    let title: String
    let description: String
    let severity: String
    let status: String
    let source: String
    let reporterEmail: String
    let metadata: Metadata
}

struct BugReportResponse: Decodable, Equatable {
    struct Report: Decodable, Equatable {
        let id: String?
    }

    struct Intake: Decodable, Equatable {
        let state: String?
        let acknowledgement: String?
    }

    let report: Report?
    let intake: Intake?
}

struct BugReportDraft {
    let title: String
    let description: String
    let severity: BugSeverity
}

struct BugReporterConfiguration {
    let appId: String
    let appName: String
    let projectPath: String
    let reporterEmail: String
    let source: String
    let apiBase: URL

    static let ninjaCamera = BugReporterConfiguration(
        appId: "ninja-camera-ios",
        appName: "NinjaCamera",
        projectPath: "/Users/yasser159/code/iOS/NinjaCamera",
        reporterEmail: "yasser159@gmail.com",
        source: "ninja-camera-ios",
        apiBase: URL(string: "https://bugs159-fe5c1.web.app/api/bugs")!
    )
}

struct BugReportService {
    let configuration: BugReporterConfiguration
    let session: URLSession

    init(
        configuration: BugReporterConfiguration = .ninjaCamera,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func makePayload(draft: BugReportDraft, recentLogs: [DiagnosticsEvent]) -> BugReportPayload {
        BugReportPayload(
            appId: configuration.appId,
            appName: configuration.appName,
            projectPath: configuration.projectPath,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: draft.severity.rawValue,
            status: "new",
            source: configuration.source,
            reporterEmail: configuration.reporterEmail,
            metadata: .init(recentLogs: recentLogs)
        )
    }

    func submit(draft: BugReportDraft, recentLogs: [DiagnosticsEvent]) async throws -> BugReportResponse {
        let payload = makePayload(draft: draft, recentLogs: recentLogs)
        var request = URLRequest(url: configuration.apiBase.appendingPathComponent("report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "BugReportService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }

        return try JSONDecoder().decode(BugReportResponse.self, from: data)
    }
}
