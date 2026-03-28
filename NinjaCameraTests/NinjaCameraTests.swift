//
//  NinjaCameraTests.swift
//  NinjaCameraTests
//
//  Created by Yasser Hajlaoui on 1/18/26.
//

import Foundation
import Testing
@testable import NinjaCamera

struct NinjaCameraTests {
    @Test func diagnosticsStoreIsBounded() async throws {
        let store = await MainActor.run { DiagnosticsStore(maxEvents: 3) }
        await MainActor.run {
            store.log(subsystem: "test", message: "one")
            store.log(subsystem: "test", message: "two")
            store.log(subsystem: "test", message: "three")
            store.log(subsystem: "test", message: "four")
        }

        let snapshot = await MainActor.run { store.snapshot() }
        #expect(snapshot.count == 3)
        #expect(snapshot.last?.message == "four")
        #expect(snapshot.first?.message == "two")
    }

    @Test func bugReportPayloadUsesExpectedDefaults() async throws {
        let service = BugReportService()
        let payload = service.makePayload(
            draft: BugReportDraft(title: "A", description: "B", severity: .high),
            recentLogs: [DiagnosticsEvent(level: .error, subsystem: "test", message: "boom")]
        )

        #expect(payload.appId == "ninja-camera-ios")
        #expect(payload.reporterEmail == "yasser159@gmail.com")
        #expect(payload.severity == "high")
        #expect(payload.metadata.recentLogs.count == 1)
    }

    @Test func timeLapseIntervalDefaultsToTwoSeconds() async throws {
        let suiteName = "NinjaCameraTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = await MainActor.run {
            CameraViewModel(
                diagnosticsStore: DiagnosticsStore(maxEvents: 10),
                bugReportService: BugReportService(),
                defaults: defaults
            )
        }

        let selectedInterval = await MainActor.run { viewModel.timeLapseInterval }
        #expect(selectedInterval == 2)
    }
}
