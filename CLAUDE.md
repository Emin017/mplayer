# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This is a Audio Player App built with Swift and SwiftUI. The app allows users to play audio files, manage playlists, and control playback. And it can also show you the waveform of the audio being played. It is designed to be simple, intuitive, and user-friendly.

## Development Commands

```bash
# Build the project
xcodebuild -project mplayer.xcodeproj -scheme mplayer -configuration Release build

# Run tests
xcodebuild test -project mplayer.xcodeproj -scheme mplayer -destination 'platform=macOS'

# Build and test (Debug configuration)
xcodebuild test -project mplayer.xcodeproj -scheme mplayer -destination 'platform=macOS' -configuration Debug

# Development shell with formatting tools (using Nix)
nix develop
```

## Architecture

- **mplayer/AudioPlayerView.swift**: Main SwiftUI view containing audio player controls, playlist management, and waveform display (2,235 lines)
- **mplayer/ContentView.swift**: Simple container view that wraps AudioPlayerView with padding
- **mplayer/mplayerApp.swift**: App entry point with TouchBar setup and remote control event handling
- **mplayerTests/mplayerTests.swift**: Unit tests using Swift Testing framework
- **mplayerUITests/mplayerUITests.swift**: UI tests using XCTest

## Key Principles Discovered

### Type Safety & Runtime Validation

- **Runtime Safety**: We should avoid runtime checks for things that can be enforced at compile time, but we can use runtime checks for things that cannot be known until runtime
- **Compile-time Safety**: Use proper typing to catch errors at compile time
- **Literal Types for Constraints**: Use literal types (e.g., enums, structs) to enforce valid values
- **Surgical Type Application**: Be strategic about where strict types vs. generic types are used

### Code Organization

- **Separation of Concerns**: Generic utilities should be reusable by other applications; application-specific code should be clearly separated
- **Descriptive Naming**: Module names must reflect their specificity - no misleadingly generic names
- **Future-Proof Guarantees**: Proper typing provides compile-time guarantees that prevent future bugs, which runtime checks cannot provide

## Key Features

- **Audio Playback**: Full-featured audio player with play, pause, stop, skip forward/backward controls
- **Playlist Management**: Add, remove, reorder tracks with drag-and-drop support and batch operations
- **Waveform Display**: Real-time waveform visualization with progress tracking and seek functionality
- **Repeat Modes**: Support for no repeat, single track repeat, and playlist repeat modes
- **Remote Control**: macOS system remote transport controls (play/pause, next/previous, seek)
- **Audio Format Support**: MP3, WAV, AAC/M4A, FLAC, AIFF, OGG with detailed format information display
- **Cover Art Extraction**: Automatic extraction of embedded cover art from audio files
- **Performance Optimized**: Waveform caching, conservative preloading, and memory-efficient processing
- **Modern SwiftUI Interface**: Clean, responsive UI with smooth animations and transitions
- **Batch Operations**: Multi-select editing with delete and move operations
- **Dark/Light Mode**: Automatic adaptation to system appearance settings

## Technical Implementation

### Core Components

- **AudioPlayerViewModel**: Main view model handling audio playback state, playlist management, and audio processing
- **AudioFile**: Data structure representing audio tracks with metadata, waveform data, and format information
- **RepeatMode**: Enum for managing repeat states (none, single, playlist)
- **PlayingIndicatorManager**: Centralized animation manager for playing indicators
- **Waveform Components**: Family of waveform views (WaveformView, EmptyWaveformView, LoadingWaveformView, PlaceholderWaveformView)

### Key Algorithms

- **Waveform Generation**: Memory-efficient audio processing with chunked reading and normalization
- **Waveform Caching**: File-based caching system with cache keys based on file attributes
- **Audio Format Detection**: Comprehensive format extraction using AVFoundation and Core Media
- **Performance Optimization**: Conservative preloading, background processing, and autorelease pools

### Dependencies

- **AVFoundation**: Core audio playback and processing
- **MediaPlayer**: Remote transport controls and now playing info
- **UniformTypeIdentifiers**: File type detection for audio files
- **CoreMedia**: Low-level audio format analysis
- **os.log**: Structured logging throughout the application

## Testing

- Build and run the app in Xcode to ensure it compiles and functions correctly.
- Use Xcode's built-in testing tools to run unit tests and UI tests, if applicable.
- Test the audio playback functionality with various audio files to ensure compatibility and performance.
- Verify that the UI elements respond correctly to user interactions.
- Ensure that the app handles edge cases, such as unsupported audio formats or network errors, gracefully