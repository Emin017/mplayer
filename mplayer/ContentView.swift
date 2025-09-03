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
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
            AudioPlayerView()
                  .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
