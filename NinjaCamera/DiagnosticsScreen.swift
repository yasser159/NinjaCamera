import SwiftUI

struct DiagnosticsScreen: View {
    @ObservedObject var viewModel: CameraViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var severity: BugSeverity = .medium
    @State private var isSubmitting = false
    @State private var submissionMessage = ""

    var body: some View {
        NavigationStack {
            List {
                statusSection
                reportSection
                logsSection
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            LabeledContent("Capture state", value: viewModel.captureState.rawValue)
            LabeledContent("Lifecycle", value: viewModel.backgroundCoordinator.lifecycleState.rawValue)
            LabeledContent("PiP", value: viewModel.backgroundCoordinator.pictureInPictureState)
            LabeledContent("Photos", value: String(viewModel.photoCount))
            if viewModel.diagnosticsStore.shouldOfferQuickReport {
                Button("Quick report recent failures") {
                    title = title.isEmpty ? "Repeated capture/lifecycle failures" : title
                    description = description.isEmpty ? "Diagnostics quick report triggered after repeated recent errors." : description
                }
            }
        }
    }

    private var reportSection: some View {
        Section("Report Issue") {
            TextField("Title", text: $title)
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
            Picker("Severity", selection: $severity) {
                ForEach(BugSeverity.allCases) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            Button(isSubmitting ? "Submitting..." : "Send to Bugs159") {
                submitReport()
            }
            .disabled(isSubmitting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !submissionMessage.isEmpty {
                Text(submissionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logsSection: some View {
        Section("Recent Logs") {
            if viewModel.diagnosticsStore.events.isEmpty {
                Text("No logs yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.diagnosticsStore.events.reversed()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("[\(event.level.rawValue)] \(event.subsystem)")
                            .font(.caption.weight(.semibold))
                        Text(event.message)
                            .font(.body)
                        if !event.metadata.isEmpty {
                            Text(event.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func submitReport() {
        let draft = BugReportDraft(
            title: title,
            description: description,
            severity: severity
        )

        isSubmitting = true
        submissionMessage = ""
        Task {
            let result = await viewModel.submitBugReport(draft: draft)
            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success(let response):
                    let acknowledgement = response.intake?.acknowledgement ?? "Bug reported."
                    submissionMessage = acknowledgement
                    title = ""
                    description = ""
                    severity = .medium
                case .failure(let error):
                    submissionMessage = error.localizedDescription
                }
            }
        }
    }
}
