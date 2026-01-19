//
//  ContentView.swift
//  NinjaCamera
//
//  Created by Yasser Hajlaoui on 1/18/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var sliderProgress: CGFloat = 0
    @State private var coverVisible = false
    @State private var coverWorkItem: DispatchWorkItem?

    private let intervals: [Double] = [5, 15, 30, 45, 60]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        modePicker
                        captureCounter
                        timeLapseControls
                        photoQuickAction
                    }
                    .padding(20)
                    .foregroundStyle(.white)
                }
                actionRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 56)
                statusPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            if coverVisible {
                Color.black
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleCoverTap()
                    }
            }
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .onChange(of: isModeActive) { _, active in
            updateCoverVisibility(isActive: active)
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

    private var background: some View {
        Group {
            Color.black
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        Image("seeying eye")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
    }

    private var statusPanel: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(viewModel.statusMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            Spacer()
            Text(viewModel.captureState.rawValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actionRow: some View {
        SlideControl(
            title: isModeActive ? "Slide to Stop" : "Slide to Start",
            icon: isModeActive ? "engine.combustion" : "eye.fill",
            tint: isModeActive ? Color.red : Color.white,
            progress: $sliderProgress
        ) {
            if isModeActive {
                viewModel.stopSelectedMode()
            } else {
                viewModel.startSelectedMode()
            }
        }
    }

    private var captureCounter: some View {
        Group {
            if isCountingModeActive {
                HStack {
                    Label("Pings captured", systemImage: "compass.drawing")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(viewModel.photoCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ping mode", systemImage: "slider.horizontal.3")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 10) {
                ForEach(captureModes) { mode in
                    Button(action: {
                        viewModel.selectedMode = mode
                        viewModel.stopAllCaptureModes()
                    }) {
                        VStack(spacing: 0) {
                            Image(systemName: modeSymbol(mode))
                                .font(.system(size: 22, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.selectedMode == mode ? Color.white : Color.white.opacity(0.12))
                        .foregroundStyle(viewModel.selectedMode == mode ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .accessibilityLabel(Text(mode.rawValue))
                }
            }
        }
    }

    private func modeSymbol(_ mode: CameraViewModel.CaptureMode) -> String {
        switch mode {
        case .photo:
            return "compass.drawing"
        case .timeLapse:
            return "timer"
        case .faceDetection:
            return "faceid"
        case .voice:
            return "mic"
        }
    }

    private var timeLapseControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ping interval", systemImage: "timer")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Picker("Interval", selection: $viewModel.timeLapseInterval) {
                ForEach(intervals, id: \.self) { interval in
                    Text("\(Int(interval))s").tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .tint(.white)
            .colorScheme(.dark)
            .onChange(of: viewModel.timeLapseInterval) { _, _ in
                if viewModel.selectedMode == .timeLapse, viewModel.isTimeLapseEnabled {
                    viewModel.startTimeLapse()
                }
                if viewModel.selectedMode == .faceDetection, viewModel.isFaceDetectionEnabled {
                    viewModel.setFaceDetectionEnabled(true)
                }
            }
            if viewModel.isTimeLapseEnabled || viewModel.isFaceDetectionEnabled {
                Text("Next shot in -\(viewModel.timeLapseCountdown)s")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .opacity((viewModel.selectedMode == .timeLapse || viewModel.selectedMode == .faceDetection) ? 1 : 0.35)
        .allowsHitTesting(viewModel.selectedMode == .timeLapse || viewModel.selectedMode == .faceDetection)
    }

    private var photoQuickAction: some View {
        Button(action: { viewModel.capturePhoto() }) {
            HStack(spacing: 10) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 16, weight: .semibold))
                Text("Pings")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.12))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var captureModes: [CameraViewModel.CaptureMode] {
        [.timeLapse, .faceDetection, .voice]
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

    private var isCountingModeActive: Bool {
        switch viewModel.selectedMode {
        case .timeLapse:
            return viewModel.isTimeLapseEnabled
        case .faceDetection:
            return viewModel.isFaceDetectionEnabled
        case .voice:
            return viewModel.isVoiceEnabled
        case .photo:
            return false
        }
    }

    private func updateCoverVisibility(isActive: Bool) {
        coverWorkItem?.cancel()
        coverWorkItem = nil
        coverVisible = isActive
    }

    private func handleCoverTap() {
        guard isModeActive else { return }
        coverVisible = false
        coverWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            if isModeActive {
                coverVisible = true
            }
        }
        coverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }

    private var statusColor: Color {
        switch viewModel.captureState {
        case .idle:
            return .green
        case .capturing, .timeLapse:
            return .yellow
        case .error:
            return .orange
        }
    }
}

private struct SlideControl: View {
    let title: String
    let icon: String
    let tint: Color
    @Binding var progress: CGFloat
    var onComplete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let height: CGFloat = 52
            let width = proxy.size.width
            let knobSize = height - 8
            let maxOffset = max(0, width - knobSize - 8)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: height)

                Capsule(style: .continuous)
                    .fill(tint.opacity(0.2))
                    .frame(width: max(52, progress), height: height)

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: height)

                Circle()
                    .fill(tint)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint == .white ? .black : .white)
                    )
                    .offset(x: min(max(progress - knobSize, 0), maxOffset))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let raw = value.translation.width + knobSize
                                progress = min(max(raw, knobSize), maxOffset + knobSize)
                            }
                            .onEnded { _ in
                                let threshold = maxOffset + knobSize * 0.6
                                if progress >= threshold {
                                    onComplete()
                                }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    progress = 0
                                }
                            }
                    )
            }
            .frame(height: height)
        }
        .frame(height: 52)
    }
}

private struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct SecondaryActionStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.red : Color.white.opacity(0.15))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview {
    ContentView()
}
