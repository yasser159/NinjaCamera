//
//  CameraSkin.swift
//  NinjaCamera
//
//  Created by Codex on 1/24/26.
//

import SwiftUI

enum CameraSkin: String, CaseIterable, Identifiable {
    case stealth
    case manuscript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stealth:
            return "Stealth"
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
