//
//  ContentView.swift
//  mplayer
//
//  Created by Emin (qiming chu) on 2025/9/3.
//
// SPDX-License-Identifier: MulanPSL-2.0
// SPDX-FileCopyrightText: 2025 Emin (Qiming Chu) <me@emin.chat>

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            AudioPlayerView()
            .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
