//
//  CameraSkin.swift
//  NinjaCamera
//
//  Created by Codex on 1/24/26.
//

import SwiftUI

enum CameraSkin: String, CaseIterable, Identifiable {
    case stealth
    case ember
    case arctic
    case manuscript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stealth:
            return "Stealth"
        case .ember:
            return "Ember"
        case .arctic:
            return "Arctic"
        case .manuscript:
            return "Manuscript"
        }
    }

    var style: CameraSkinStyle {
        switch self {
        case .stealth:
            return CameraSkinStyle(
                background: LinearGradient(
                    colors: [Color.black, Color(red: 0.08, green: 0.09, blue: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryText: .white,
                secondaryText: Color.white.opacity(0.7),
                panel: Color.white.opacity(0.08),
                panelMuted: Color.white.opacity(0.12),
                panelStrong: .white,
                accent: .white,
                accentForeground: .black,
                danger: Color.red,
                dangerForeground: .white,
                actionButtonBackground: Color.white.opacity(0.12),
                actionButtonText: .white,
                sliderTrack: Color.white.opacity(0.08),
                coverColor: Color.black.opacity(0.85),
                statusIdle: .green,
                statusActive: .yellow,
                statusError: .orange,
                pickerTint: .white,
                pickerScheme: .dark
            )
        case .ember:
            return CameraSkinStyle(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.05, blue: 0.02),
                        Color(red: 0.35, green: 0.12, blue: 0.05),
                        Color(red: 0.06, green: 0.09, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryText: Color(red: 0.99, green: 0.95, blue: 0.90),
                secondaryText: Color(red: 0.99, green: 0.91, blue: 0.82, opacity: 0.7),
                panel: Color.black.opacity(0.25),
                panelMuted: Color(red: 0.98, green: 0.74, blue: 0.42, opacity: 0.18),
                panelStrong: Color(red: 0.98, green: 0.74, blue: 0.42),
                accent: Color(red: 0.98, green: 0.74, blue: 0.42),
                accentForeground: Color(red: 0.18, green: 0.07, blue: 0.02),
                danger: Color(red: 0.92, green: 0.26, blue: 0.18),
                dangerForeground: .white,
                actionButtonBackground: Color(red: 0.98, green: 0.74, blue: 0.42, opacity: 0.2),
                actionButtonText: Color(red: 0.99, green: 0.95, blue: 0.90),
                sliderTrack: Color.black.opacity(0.22),
                coverColor: Color.black.opacity(0.78),
                statusIdle: Color(red: 0.38, green: 0.82, blue: 0.62),
                statusActive: Color(red: 0.98, green: 0.78, blue: 0.36),
                statusError: Color(red: 0.97, green: 0.33, blue: 0.20),
                pickerTint: Color(red: 0.98, green: 0.74, blue: 0.42),
                pickerScheme: .dark
            )
        case .arctic:
            return CameraSkinStyle(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.12, blue: 0.18),
                        Color(red: 0.08, green: 0.30, blue: 0.38),
                        Color(red: 0.03, green: 0.15, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryText: Color(red: 0.90, green: 0.98, blue: 1.0),
                secondaryText: Color(red: 0.84, green: 0.95, blue: 0.98, opacity: 0.7),
                panel: Color.white.opacity(0.10),
                panelMuted: Color.white.opacity(0.18),
                panelStrong: Color(red: 0.70, green: 0.95, blue: 1.0),
                accent: Color(red: 0.70, green: 0.95, blue: 1.0),
                accentForeground: Color(red: 0.03, green: 0.15, blue: 0.20),
                danger: Color(red: 0.95, green: 0.34, blue: 0.32),
                dangerForeground: .white,
                actionButtonBackground: Color.white.opacity(0.16),
                actionButtonText: Color(red: 0.90, green: 0.98, blue: 1.0),
                sliderTrack: Color.white.opacity(0.1),
                coverColor: Color.black.opacity(0.82),
                statusIdle: Color(red: 0.35, green: 0.92, blue: 0.82),
                statusActive: Color(red: 0.98, green: 0.82, blue: 0.50),
                statusError: Color(red: 0.97, green: 0.36, blue: 0.32),
                pickerTint: Color(red: 0.70, green: 0.95, blue: 1.0),
                pickerScheme: .dark
            )
        case .manuscript:
            return CameraSkinStyle(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.94, blue: 0.90),
                        Color(red: 0.92, green: 0.90, blue: 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryText: Color(red: 0.12, green: 0.12, blue: 0.12),
                secondaryText: Color(red: 0.30, green: 0.28, blue: 0.26),
                panel: Color.black.opacity(0.04),
                panelMuted: Color.black.opacity(0.06),
                panelStrong: Color.black.opacity(0.12),
                accent: Color(red: 0.12, green: 0.12, blue: 0.12),
                accentForeground: Color(red: 0.96, green: 0.94, blue: 0.90),
                danger: Color(red: 0.62, green: 0.18, blue: 0.12),
                dangerForeground: Color(red: 0.98, green: 0.96, blue: 0.92),
                actionButtonBackground: Color.black.opacity(0.08),
                actionButtonText: Color(red: 0.12, green: 0.12, blue: 0.12),
                sliderTrack: Color.black.opacity(0.06),
                coverColor: Color.black.opacity(0.7),
                statusIdle: Color(red: 0.16, green: 0.48, blue: 0.32),
                statusActive: Color(red: 0.68, green: 0.44, blue: 0.12),
                statusError: Color(red: 0.62, green: 0.18, blue: 0.12),
                pickerTint: Color(red: 0.20, green: 0.20, blue: 0.20),
                pickerScheme: .light
            )
        }
    }
}

struct CameraSkinStyle {
    let background: LinearGradient
    let primaryText: Color
    let secondaryText: Color
    let panel: Color
    let panelMuted: Color
    let panelStrong: Color
    let accent: Color
    let accentForeground: Color
    let danger: Color
    let dangerForeground: Color
    let actionButtonBackground: Color
    let actionButtonText: Color
    let sliderTrack: Color
    let coverColor: Color
    let statusIdle: Color
    let statusActive: Color
    let statusError: Color
    let pickerTint: Color
    let pickerScheme: ColorScheme
}
