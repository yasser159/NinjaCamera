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
            VStack(spacing: 16) {
                header
                statusPanel
                actionRow
                modeToggles
                timeLapseControls
                confirmationControls
                complianceNote
                Spacer(minLength: 0)
            }
            .padding(20)
            .foregroundStyle(.white)
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
            if viewModel.isDiscreetMode {
                Color.black
            } else {
                LinearGradient(colors: [Color.black, Color.gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Discreet Camera")
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
        HStack(spacing: 12) {
            Button(action: { viewModel.capturePhoto() }) {
                Label("Photo", systemImage: "camera")
            }
            .buttonStyle(PrimaryActionStyle())

            Button(action: {
                viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
            }) {
                Label(viewModel.isRecording ? "Stop" : "Video", systemImage: viewModel.isRecording ? "stop.fill" : "video")
            }
            .buttonStyle(SecondaryActionStyle(isActive: viewModel.isRecording))
        }
    }

    private var modeToggles: some View {
        VStack(spacing: 12) {
            Toggle("Screen-off capture (dim screen)", isOn: Binding(get: {
                viewModel.isDiscreetMode
            }, set: { value in
                viewModel.setDiscreetMode(value)
            }))
            Toggle("Voice commands", isOn: Binding(get: {
                viewModel.isVoiceEnabled
            }, set: { value in
                viewModel.setVoiceEnabled(value)
            }))
            Toggle("Time-lapse", isOn: Binding(get: {
                viewModel.isTimeLapseEnabled
            }, set: { value in
                viewModel.toggleTimeLapse(value)
            }))
        }
        .toggleStyle(SwitchToggleStyle(tint: .white))
    }

    private var timeLapseControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time-lapse interval")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Picker("Interval", selection: $viewModel.timeLapseInterval) {
                ForEach(intervals, id: \.self) { interval in
                    Text("\(Int(interval))s").tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.timeLapseInterval) { _ in
                if viewModel.isTimeLapseEnabled {
                    viewModel.startTimeLapse()
                }
            }
        }
    }

    private var confirmationControls: some View {
        VStack(spacing: 12) {
            Toggle("Haptic confirmation", isOn: $viewModel.hapticsEnabled)
            Toggle("Audio confirmation", isOn: $viewModel.audioConfirmationEnabled)
        }
        .toggleStyle(SwitchToggleStyle(tint: .white))
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
