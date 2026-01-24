//
//  TextFileSkinView.swift
//  NinjaCamera
//
//  Created by Codex on 1/24/26.
//

import SwiftUI

struct TextFileSkinView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Binding var selectedSkin: CameraSkin
    let style: CameraSkinStyle

    @Environment(\.colorScheme) private var colorScheme

    private let intervals: [Double] = [5, 15, 30, 45, 60]
    private let tapHoldDuration: TimeInterval = 2

    @State private var transientActiveActions: Set<StoryAction> = []
    @State private var transientStatusText: String?
    @State private var statusWorkItem: DispatchWorkItem?

    var body: some View {
        let activeStyle = manuscriptStyle
        ZStack {
            activeStyle.background
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    skinLine
                    storyBlock
                    statusBlock
                }
                .padding(24)
            }
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .onChange(of: viewModel.statusMessage) { _, newValue in
            showStatusLine(newValue)
        }
        .alert("Issue", isPresented: Binding(get: {
            viewModel.lastError != nil
        }, set: { newValue in
            if !newValue {
                viewModel.lastError = nil
            }
        }), actions: {
            Button("OK") { viewModel.lastError = nil }
        }, message: {
            Text(viewModel.lastError ?? "Unknown error")
        })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Session notes, tap words to act")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(manuscriptStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var skinLine: some View {
        HStack(spacing: 8) {
            Text("skins:")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(manuscriptStyle.secondaryText)
            ForEach(CameraSkin.allCases) { skin in
                Button(action: { selectedSkin = skin }) {
                    Text(skin.displayName.lowercased())
                        .font(.system(size: 12, weight: selectedSkin == skin ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(manuscriptStyle.primaryText)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var storyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Entry")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(style.secondaryText)
            FlowLayout(spacing: 6, lineSpacing: 10) {
                ForEach(storyTokens) { token in
                    if let action = token.action {
                        let isActive = isActionActive(action) || transientActiveActions.contains(action)
                        Button(action: { perform(action) }) {
                            Text(token.text)
                                .font(.system(size: 16, weight: isActive ? .heavy : .regular, design: .monospaced))
                                .foregroundStyle(manuscriptStyle.primaryText)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 2)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(token.text)
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundStyle(manuscriptStyle.primaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private var statusBlock: some View {
        Group {
            if let transientStatusText {
                Text(transientStatusText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(manuscriptStyle.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.captureState {
        case .idle:
            return manuscriptStyle.statusIdle
        case .capturing, .timeLapse:
            return manuscriptStyle.statusActive
        case .error:
            return manuscriptStyle.statusError
        }
    }

    private var manuscriptStyle: CameraSkinStyle {
        if colorScheme == .dark {
            return CameraSkinStyle(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.09),
                        Color(red: 0.12, green: 0.12, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryText: Color(red: 0.94, green: 0.93, blue: 0.90),
                secondaryText: Color(red: 0.78, green: 0.76, blue: 0.72),
                panel: Color.white.opacity(0.06),
                panelMuted: Color.white.opacity(0.08),
                panelStrong: Color.white.opacity(0.12),
                accent: Color(red: 0.94, green: 0.93, blue: 0.90),
                accentForeground: Color(red: 0.10, green: 0.10, blue: 0.10),
                danger: Color(red: 0.82, green: 0.34, blue: 0.26),
                dangerForeground: .black,
                actionButtonBackground: Color.white.opacity(0.12),
                actionButtonText: Color(red: 0.94, green: 0.93, blue: 0.90),
                sliderTrack: Color.white.opacity(0.08),
                coverColor: Color.black.opacity(0.8),
                statusIdle: Color(red: 0.42, green: 0.78, blue: 0.62),
                statusActive: Color(red: 0.86, green: 0.68, blue: 0.32),
                statusError: Color(red: 0.88, green: 0.36, blue: 0.28),
                pickerTint: Color(red: 0.94, green: 0.93, blue: 0.90),
                pickerScheme: .dark
            )
        }

        return style
    }

    private func perform(_ action: StoryAction) {
        holdActive(action)
        showStatusLine(statusLine(for: action))
        switch action {
        case .setMode(let mode):
            viewModel.selectedMode = mode
            viewModel.stopAllCaptureModes()
        case .start:
            viewModel.startSelectedMode()
        case .stop:
            viewModel.stopSelectedMode()
        case .capture:
            viewModel.capturePhoto()
        case .toggleDiscreet:
            viewModel.setDiscreetMode(!viewModel.isDiscreetMode)
        case .cycleInterval:
            guard let idx = intervals.firstIndex(of: viewModel.timeLapseInterval) else {
                viewModel.timeLapseInterval = intervals[0]
                return
            }
            let next = intervals[(idx + 1) % intervals.count]
            viewModel.timeLapseInterval = next
            if viewModel.selectedMode == .timeLapse, viewModel.isTimeLapseEnabled {
                viewModel.startTimeLapse()
            }
            if viewModel.selectedMode == .faceDetection, viewModel.isFaceDetectionEnabled {
                viewModel.setFaceDetectionEnabled(true)
            }
        }
    }

    private func holdActive(_ action: StoryAction) {
        transientActiveActions.insert(action)
        DispatchQueue.main.asyncAfter(deadline: .now() + tapHoldDuration) {
            transientActiveActions.remove(action)
        }
    }

    private func showStatusLine(_ text: String) {
        statusWorkItem?.cancel()
        statusWorkItem = nil
        transientStatusText = text
        let workItem = DispatchWorkItem {
            transientStatusText = nil
        }
        statusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + tapHoldDuration, execute: workItem)
    }

    private func statusLine(for action: StoryAction) -> String {
        switch action {
        case .setMode(let mode):
            return "mode set: \(mode.rawValue)"
        case .start:
            return "run started"
        case .stop:
            return "run stopped"
        case .capture:
            return "single ping"
        case .toggleDiscreet:
            return viewModel.isDiscreetMode ? "discreet off" : "discreet on"
        case .cycleInterval:
            return "interval: \(Int(viewModel.timeLapseInterval))s"
        }
    }

    private func isActionActive(_ action: StoryAction) -> Bool {
        switch action {
        case .setMode(let mode):
            return viewModel.selectedMode == mode
        case .start:
            return isModeActive
        case .stop:
            return false
        case .capture:
            return false
        case .toggleDiscreet:
            return viewModel.isDiscreetMode
        case .cycleInterval:
            return false
        }
    }

    private var isModeActive: Bool {
        switch viewModel.selectedMode {
        case .photo:
            return false
        case .timeLapse:
            return viewModel.isTimeLapseEnabled
        case .faceDetection:
            return viewModel.isFaceDetectionEnabled
        case .voice:
            return viewModel.isVoiceEnabled
        }
    }

    private var storyTokens: [StoryToken] {
        [
            "Tonight the alley is quiet, but the".plain(),
            "watch".action(.setMode(.faceDetection)),
            "keeps its own counsel.".plain(),
            "I".plain(),
            "listen".action(.setMode(.voice)),
            "for the whisper, or I".plain(),
            "wait".action(.setMode(.timeLapse)),
            "for the".plain(),
            "timer".action(.cycleInterval),
            "to return.".plain(),
            "When the moment bends, I".plain(),
            "capture".action(.capture),
            "a trace and".plain(),
            "start".action(.start),
            "the run; if the street goes loud, I".plain(),
            "stop".action(.stop),
            "and".plain(),
            "shadow".action(.toggleDiscreet),
            "the light.".plain()
        ]
        .flatMap { $0 }
    }
}

private struct StoryToken: Identifiable {
    let id = UUID()
    let text: String
    let action: StoryAction?
}

private enum StoryAction: Hashable {
    case setMode(CameraViewModel.CaptureMode)
    case start
    case stop
    case capture
    case toggleDiscreet
    case cycleInterval
}

private extension String {
    func plain() -> [StoryToken] {
        splitTokens(action: nil)
    }

    func action(_ action: StoryAction) -> [StoryToken] {
        splitTokens(action: action)
    }

    private func splitTokens(action: StoryAction?) -> [StoryToken] {
        var tokens: [StoryToken] = []
        let parts = self.split(separator: " ")
        for part in parts {
            tokens.append(StoryToken(text: String(part), action: action))
        }
        return tokens
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? CGFloat.greatestFiniteMagnitude
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + lineSpacing
                totalWidth = max(totalWidth, lineWidth)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        totalHeight += lineHeight
        totalWidth = max(totalWidth, lineWidth)

        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    TextFileSkinView(viewModel: CameraViewModel(), selectedSkin: .constant(.manuscript), style: CameraSkin.manuscript.style)
}
