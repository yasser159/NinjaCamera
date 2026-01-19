//
//  ContentView.swift
//  NinjaCamera
//
//  Created by Yasser Hajlaoui on 1/18/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    private let intervals: [Double] = [15, 30, 45, 60]

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    statusPanel
                modePicker
                actionRow
                modeToggles
                timeLapseControls
                // confirmationControls
                complianceNote
                }
                .padding(20)
                .foregroundStyle(.white)
            }
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
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
        VStack(spacing: 6) {
            Text("Zero Camera")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("Minimal capture controls")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
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
        Button(action: {
            if isModeActive {
                viewModel.stopSelectedMode()
            } else {
                viewModel.startSelectedMode()
            }
        }) {
            Label(isModeActive ? "Stop" : "Start", systemImage: isModeActive ? "stop.fill" : "play.fill")
        }
        .buttonStyle(PrimaryActionStyle())
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Capture mode", systemImage: "slider.horizontal.3")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 10) {
                ForEach(CameraViewModel.CaptureMode.allCases) { mode in
                    Button(action: {
                        viewModel.selectedMode = mode
                        viewModel.stopAllCaptureModes()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: modeSymbol(mode))
                                .font(.system(size: 16, weight: .semibold))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
            return "camera"
        case .video:
            return "video"
        case .timeLapse:
            return "timer"
        case .faceDetection:
            return "faceid"
        case .voice:
            return "mic"
        }
    }

    private var modeToggles: some View {
        VStack(spacing: 12) {
            Toggle(isOn: Binding(get: {
                viewModel.isDiscreetMode
            }, set: { value in
                viewModel.setDiscreetMode(value)
            })) {
                Label("Screen-off capture (dim screen)", systemImage: "eye.slash")
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .white))
    }

    private var timeLapseControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Time-lapse interval", systemImage: "timer")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Picker("Interval", selection: $viewModel.timeLapseInterval) {
                ForEach(intervals, id: \.self) { interval in
                    Text("\(Int(interval))s").tag(interval)
                }
            }
            .pickerStyle(.segmented)
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
    }

    private var isModeActive: Bool {
        switch viewModel.selectedMode {
        case .photo:
            return false
        case .video:
            return viewModel.isRecording
        case .timeLapse:
            return viewModel.isTimeLapseEnabled
        case .faceDetection:
            return viewModel.isFaceDetectionEnabled
        case .voice:
            return viewModel.isVoiceEnabled
        }
    }

    private var complianceNote: some View {
        Text("Capture requires the app to stay in the foreground. iOS blocks camera access when the screen is locked or the app is in the background.")
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
    }

    private var statusColor: Color {
        switch viewModel.captureState {
        case .idle:
            return .green
        case .capturing, .timeLapse:
            return .yellow
        case .recording:
            return .red
        case .error:
            return .orange
        }
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
