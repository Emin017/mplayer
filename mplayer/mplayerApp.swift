//
//  mplayerApp.swift
//  mplayer
//
//  Created by Emin (qiming chu) on 2025/9/3.
//

import SwiftUI
import MediaPlayer

@main
struct mplayerApp: App {
    init() {
        // Enable remote control event reception for media control
        NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
