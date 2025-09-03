//
//  ContentView.swift
//  mplayer
//
//  Created by Emin (qiming chu) on 2025/9/3.
//

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
