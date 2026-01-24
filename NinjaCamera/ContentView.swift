//
//  ContentView.swift
//  NinjaCamera
//
//  Created by Yasser Hajlaoui on 1/18/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @AppStorage("cameraSkin") private var selectedSkinRawValue = CameraSkin.stealth.rawValue

    private var selectedSkin: CameraSkin {
        CameraSkin(rawValue: selectedSkinRawValue) ?? .stealth
    }

    private var skinBinding: Binding<CameraSkin> {
        Binding(
            get: { CameraSkin(rawValue: selectedSkinRawValue) ?? .stealth },
            set: { selectedSkinRawValue = $0.rawValue }
        )
    }

    var body: some View {
        CameraScreen(viewModel: viewModel, selectedSkin: skinBinding)
    }
}

#Preview {
    ContentView()
}
