//
//  AudioPlayerView.swift
//  mplayer
//
//  Created by Emin (Qiming Chu) on 2025/9/3.
//
// SPDX-License-Identifier: MulanPSL-2.0
// SPDX-FileCopyrightText: 2025 Emin (Qiming Chu) <me@emin.chat>

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import os.log
import AVKit
import MediaPlayer
import CoreMedia

// Logger instance
private let logger = Logger(subsystem: "com.mplayer.audioPlayer", category: "AudioPlayerView")

// Repeat mode enumeration
enum RepeatMode: String, CaseIterable {
    case none = "none"
    case single = "single"
    case playlist = "playlist"

    var iconName: String {
        switch self {
        case .none:
            return "repeat"
        case .single:
            return "repeat.1"
        case .playlist:
            return "repeat"
        }
    }

    var description: String {
        switch self {
        case .none:
            return "No repeat"
        case .single:
            return "Repeat current song"
        case .playlist:
            return "Repeat playlist"
        }
    }
}

// Audio file data structure
struct AudioFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    var duration: Double = 0
    var durationString: String = "00:00"
    var coverImage: NSImage? = nil
    var waveformData: [Float] = []
    var isWaveformGenerated: Bool = false
    var isProcessing: Bool = false

    // Audio format information
    var format: String = "Unknown"
    var sampleRate: String = "Unknown"
    var bitDepth: String = "Unknown"
    var bitRate: String = "Unknown"
    var channels: String = "Unknown"
    var codec: String = "Unknown"
}

struct AudioPlayerView: View {
    @StateObject private var playerViewModel = AudioPlayerViewModel()
    @State private var isEditMode: Bool = false
    @State private var selectedItems: Set<UUID> = []

    var body: some View {
        VStack(spacing: 15) {
            // Top playback control area
            VStack(spacing: 15) {
                // Current audio info and title with cover image
                HStack {
                    // Album cover
                    Group {
                        if let currentIndex = playerViewModel.currentIndex,
                            currentIndex < playerViewModel.audioFiles.count,
                            let coverImage = playerViewModel.audioFiles[currentIndex].coverImage {
                            Image(nsImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                                .shadow(radius: 4)
                        } else {
                            // Default cover placeholder
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                )
                                .shadow(radius: 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio Player")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        Text(playerViewModel.currentAudioName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    // Audio information panel - simplified single line format
                    if let currentIndex = playerViewModel.currentIndex,
                        currentIndex < playerViewModel.audioFiles.count {
                        let currentAudio = playerViewModel.audioFiles[currentIndex]
                        VStack(alignment: .trailing, spacing: 4) {
                            // Format info in one line: MP3/CBR 320kbps 44100Hz stereo
                            Text("\(currentAudio.format) \(currentAudio.bitRate) \(currentAudio.sampleRate) \(currentAudio.channels)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            // Codec info on second line if different from format
                            if currentAudio.codec != currentAudio.format && currentAudio.codec != "Unknown" {
                                Text("编码: \(currentAudio.codec)")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal)

                // Waveform progress bar
                VStack(spacing: 8) {
                    HStack {
                        Text(playerViewModel.currentTimeString)
                            .font(.system(size: 14))
                            .monospacedDigit()

                        Spacer()

                        Text(playerViewModel.durationString)
                            .font(.system(size: 14))
                            .monospacedDigit()
                    }

                    if let currentIndex = playerViewModel.currentIndex,
                        currentIndex < playerViewModel.audioFiles.count {
                        let currentAudio = playerViewModel.audioFiles[currentIndex]

                        if !currentAudio.waveformData.isEmpty {
                            // Show real waveform when waveform data is available
                            WaveformView(
                                waveformData: currentAudio.waveformData,
                                currentTime: $playerViewModel.currentTime,
                                duration: playerViewModel.duration,
                                onSeek: { time in
                                    playerViewModel.seek(to: time)
                                }
                            )
                        } else if currentAudio.isProcessing {
                            // Show loading waveform when waveform is being generated
                            LoadingWaveformView(
                                currentTime: $playerViewModel.currentTime,
                                duration: playerViewModel.duration,
                                onSeek: { time in
                                    playerViewModel.seek(to: time)
                                }
                            )
                        } else {
                            // Show placeholder waveform when no waveform generation has started
                            PlaceholderWaveformView(
                                currentTime: $playerViewModel.currentTime,
                                duration: playerViewModel.duration,
                                onSeek: { time in
                                    playerViewModel.seek(to: time)
                                }
                            )
                        }
                    } else {
                        // Show empty waveform when no audio is loaded
                        EmptyWaveformView(
                            currentTime: $playerViewModel.currentTime,
                            duration: playerViewModel.duration,
                            onSeek: { time in
                                playerViewModel.seek(to: time)
                            }
                        )
                    }
                }
                .padding(.horizontal)

                // Playback control buttons
                HStack(spacing: 25) {
                    // Add audio button
                    Button("Add Audio") {
                        playerViewModel.selectAudioFiles()
                    }
                    .buttonStyle(.bordered)

                    // Previous button
                    Button(action: {
                        playerViewModel.playPrevious()
                    }) {
                        Image(systemName: "backward.circle.fill")
                            .resizable()
                            .frame(width: 35, height: 35)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(playerViewModel.currentIndex == nil || playerViewModel.currentIndex == 0)

                    // Play/pause button
                    Button(action: {
                        playerViewModel.playPause()
                    }) {
                        Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 45, height: 45)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Next button
                    Button(action: {
                        playerViewModel.playNext()
                    }) {
                        Image(systemName: "forward.circle.fill")
                            .resizable()
                            .frame(width: 35, height: 35)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(playerViewModel.currentIndex == nil ||
                             (playerViewModel.currentIndex == playerViewModel.audioFiles.count - 1 &&
                              playerViewModel.repeatMode == .none))

                    // Stop button
                    Button(action: {
                        playerViewModel.stop()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .resizable()
                            .frame(width: 35, height: 35)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Secondary control buttons
                HStack(spacing: 20) {
                    Spacer()

                    // Repeat mode button
                    Button(action: {
                        playerViewModel.toggleRepeatMode()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: playerViewModel.repeatMode.iconName)
                                .foregroundColor(playerViewModel.repeatMode == .none ? .secondary : .primary)
                                .font(.system(size: 16, weight: .medium))
                            Text(playerViewModel.repeatMode.description)
                                .font(.caption)
                                .foregroundColor(playerViewModel.repeatMode == .none ? .secondary : .primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(playerViewModel.repeatMode == .none ?
                                      Color.clear :
                                      Color.accentColor.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(playerViewModel.repeatMode == .none ?
                                               Color.secondary.opacity(0.3) :
                                               Color.accentColor.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(playerViewModel.repeatMode.description)

                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
            )
            .padding(.horizontal)

            // Loading progress indicator
            if playerViewModel.isLoadingFiles {
                VStack(spacing: 8) {
                    HStack {
                        Text("Loading audio files...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(playerViewModel.loadingProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: playerViewModel.loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))

                    if !playerViewModel.loadingFileName.isEmpty {
                        Text("Processing: \(playerViewModel.loadingFileName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        )
                )
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Playlist area
            VStack(alignment: .leading, spacing: 10) {
                // Playlist title
                HStack {
                    Text("Playlist")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()

                    // Batch operation buttons (only shown in edit mode)
                    if isEditMode {
                        // Select All / Deselect All button
                        Button(selectedItems.count == playerViewModel.audioFiles.count ? "Deselect All" : "Select All") {
                            if selectedItems.count == playerViewModel.audioFiles.count {
                                selectedItems.removeAll()
                            } else {
                                selectedItems = Set(playerViewModel.audioFiles.map { $0.id })
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .disabled(playerViewModel.audioFiles.isEmpty)

                        // Delete Selected button
                        Button("Delete Selected") {
                            deleteSelectedItems()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                        .disabled(selectedItems.isEmpty)
                    }

                    // Edit mode toggle button
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditMode.toggle()
                            // Clear selections when exiting edit mode
                            if !isEditMode {
                                selectedItems.removeAll()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)

                    Text("\(playerViewModel.audioFiles.count) songs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Playlist
                List {
                    ForEach(playerViewModel.audioFiles.indices, id: \.self) { index in
                        let audio = playerViewModel.audioFiles[index]
                        AudioRowView(
                            audio: audio,
                            index: index,
                            isEditMode: isEditMode,
                            isSelected: selectedItems.contains(audio.id),
                            isCurrentlyPlaying: playerViewModel.currentIndex == index && playerViewModel.isPlaying,
                            isCurrentTrack: playerViewModel.currentIndex == index,
                            onSelectionToggle: { toggleSelection(for: audio.id) },
                            onPlayAction: {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.playAtIndex(actualIndex, autoPlay: true)
                                }
                            },
                            onMoveUp: {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioUp(from: actualIndex)
                                }
                            },
                            onMoveDown: {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioDown(from: actualIndex)
                                }
                            },
                            onMoveToTop: {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioToTop(from: actualIndex)
                                }
                            },
                            onMoveToBottom: {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioToBottom(from: actualIndex)
                                }
                            },
                            onRemove: {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.removeAudio(at: IndexSet([actualIndex]))
                                }
                            },
                            playerViewModel: playerViewModel
                        )
                    }
                    .onDelete(perform: playerViewModel.removeAudio)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        )
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleSelection(for audioId: UUID) {
        if selectedItems.contains(audioId) {
            selectedItems.remove(audioId)
        } else {
            selectedItems.insert(audioId)
        }
    }

    private func deleteSelectedItems() {
        // Convert selected UUIDs to indices
        let selectedIndices = playerViewModel.audioFiles.enumerated().compactMap { index, audio in
            selectedItems.contains(audio.id) ? index : nil
        }

        // Create IndexSet from selected indices
        let indexSet = IndexSet(selectedIndices)

        // Remove the selected items
        playerViewModel.removeAudio(at: indexSet)

        // Clear selection after deletion
        selectedItems.removeAll()
    }
}

class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var audioFiles: [AudioFile] = []
    @Published var currentIndex: Int? = nil
    @Published var currentAudioName: String = "No audio selected"
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentTimeString: String = "00:00"
    @Published var durationString: String = "00:00"
    @Published var repeatMode: RepeatMode = .none
    @Published var isLoadingFiles: Bool = false
    @Published var loadingProgress: Double = 0
    @Published var loadingFileName: String = ""

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    // Logger instance
    private let logger = Logger(subsystem: "com.mplayer.audioPlayer", category: "AudioPlayerViewModel")

    // Waveform cache directory
    private lazy var waveformCacheDirectory: URL = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let waveformCacheDir = cacheDir.appendingPathComponent("WaveformCache")

        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: waveformCacheDir, withIntermediateDirectories: true)

        return waveformCacheDir
    }()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        setupRemoteTransportControls()

        // Clean up old cached waveform files on startup
        cleanupWaveformCache()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Waveform Caching

    // Generate cache key from audio file URL and modification date
    private func waveformCacheKey(for url: URL) -> String? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modificationDate = resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0
            let fileSize = resourceValues.fileSize ?? 0

            // Create a unique key based on file path, size, and modification date
            let keyString = "\(url.path)-\(fileSize)-\(Int(modificationDate))"
            return keyString.data(using: .utf8)?.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
        } catch {
            logger.error("❌ Failed to get file attributes for cache key: \(error.localizedDescription)")
            return nil
        }
    }

    // Load waveform data from cache
    private func loadCachedWaveformData(for url: URL) -> [Float]? {
        guard let cacheKey = waveformCacheKey(for: url) else { return nil }

        let cacheFileURL = waveformCacheDirectory.appendingPathComponent("\(cacheKey).waveform")

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let waveformData = try JSONDecoder().decode([Float].self, from: data)
            logger.debug("💾 Loaded cached waveform data for: \(url.lastPathComponent)")
            return waveformData
        } catch {
            logger.debug("🔍 No cached waveform data found for: \(url.lastPathComponent)")
            return nil
        }
    }

    // Save waveform data to cache
    private func saveCachedWaveformData(_ waveformData: [Float], for url: URL) {
        guard let cacheKey = waveformCacheKey(for: url) else { return }

        let cacheFileURL = waveformCacheDirectory.appendingPathComponent("\(cacheKey).waveform")

        do {
            let data = try JSONEncoder().encode(waveformData)
            try data.write(to: cacheFileURL)
            logger.debug("💾 Cached waveform data for: \(url.lastPathComponent)")
        } catch {
            logger.error("❌ Failed to cache waveform data: \(error.localizedDescription)")
        }
    }

    // Clean up old cache files (call periodically)
    func cleanupWaveformCache() {
        DispatchQueue.global(qos: .utility).async {
            do {
                let cacheFiles = try FileManager.default.contentsOfDirectory(at: self.waveformCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
                let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

                var removedCount = 0
                for fileURL in cacheFiles {
                    if let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       modificationDate < oneWeekAgo {
                        try? FileManager.default.removeItem(at: fileURL)
                        removedCount += 1
                    }
                }

                if removedCount > 0 {
                    self.logger.info("🧹 Cleaned up \(removedCount) old waveform cache files")
                }
            } catch {
                self.logger.error("❌ Error cleaning up waveform cache: \(error.localizedDescription)")
            }
        }
    }

    @objc private func handleAudioDidFinishPlaying() {
        // This notification is handled by the AVAudioPlayerDelegate method
        // Avoid duplicate calls to prevent state racing
        logger.debug("🎵 Audio did finish playing notification received")
    }

    // MARK: - Remote Transport Controls Setup
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.addTarget { [weak self] event in
            if let self = self, let player = self.audioPlayer {
                if !self.isPlaying {
                    player.play()
                    self.isPlaying = true
                    self.startTimer()
                    self.updateNowPlayingInfo()
                    self.logger.info("▶️ Remote play command executed")
                }
                return .success
            }
            return .commandFailed
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            if let self = self, let player = self.audioPlayer {
                if self.isPlaying {
                    player.pause()
                    self.isPlaying = false
                    self.stopTimer()
                    self.updateNowPlayingInfo()
                    self.logger.info("⏸️ Remote pause command executed")
                }
                return .success
            }
            return .commandFailed
        }

        // Previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            if let self = self {
                self.playPrevious()
                self.logger.info("⏮️ Remote previous command executed")
                return .success
            }
            return .commandFailed
        }

        // Next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            if let self = self {
                self.playNext()
                self.logger.info("⏭️ Remote next command executed")
                return .success
            }
            return .commandFailed
        }

        // Stop command
        commandCenter.stopCommand.addTarget { [weak self] event in
            if let self = self {
                self.stop()
                self.logger.info("⏹️ Remote stop command executed")
                return .success
            }
            return .commandFailed
        }

        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            if let self = self {
                self.playPause()
                self.logger.info("⏯️ Remote toggle play/pause command executed")
                return .success
            }
            return .commandFailed
        }

        // Position change command (seeking)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let self = self,
            let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self.seek(to: positionEvent.positionTime)
                self.logger.info("🎯 Remote seek command executed to \(positionEvent.positionTime)")
                return .success
            }
            return .commandFailed
        }

        logger.info("🎛️ Remote transport controls configured")
    }

    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let currentIndex = currentIndex,
                currentIndex < audioFiles.count else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let currentAudio = audioFiles[currentIndex]
        var nowPlayingInfo = [String: Any]()

        // Basic info
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentAudio.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Audio Player"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Playlist"

        // Timing info
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // Track info
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = currentIndex + 1
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = audioFiles.count

        // Artwork
        if let coverImage = currentAudio.coverImage {
            let artwork = MPMediaItemArtwork(boundsSize: coverImage.size) { _ in
                return coverImage
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        logger.debug("📱 Now playing info updated for: \(currentAudio.name)")
    }

    func selectAudioFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.mp3, UTType.wav, UTType.mpeg4Audio, UTType.aiff]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls.filter { url in
                !audioFiles.contains(where: { $0.url == url })
            }

            guard !urls.isEmpty else {
                logger.debug("❌ No new files to add")
                return
            }

            logger.info("📁 Selected \(urls.count) new audio files")

            // Show loading indicator
            DispatchQueue.main.async {
                self.isLoadingFiles = true
                self.loadingProgress = 0
                self.loadingFileName = ""
            }

            // Process files in background
            DispatchQueue.global(qos: .userInitiated).async {
                self.processAudioFiles(urls: urls)
            }
        } else {
            logger.debug("❌ Audio file selection cancelled")
        }
    }

    private func processAudioFiles(urls: [URL]) {
        let totalFiles = urls.count
        var processedFiles = 0
        var newAudioFiles: [AudioFile] = []

        for url in urls {
            autoreleasepool {
                processedFiles += 1
                let progress = Double(processedFiles) / Double(totalFiles)

                // Update progress on main thread
                DispatchQueue.main.async {
                    self.loadingProgress = progress
                    self.loadingFileName = url.lastPathComponent
                }

                // Create basic audio file with minimal processing
                var newAudio = AudioFile(url: url, name: url.lastPathComponent)
                newAudio.isProcessing = true

                // Extract only essential metadata (lightweight operations)
                self.extractBasicMetadata(for: &newAudio)

                // Extract audio format info (still needed for display)
                newAudio = self.extractAudioFormatInfo(for: newAudio)

                // Mark as not processing basic info
                newAudio.isProcessing = false

                newAudioFiles.append(newAudio)
                self.logger.debug("➕ Processed basic info for: \(newAudio.name)")
            }
        }

        // Add all processed files to the main array on main thread
        DispatchQueue.main.async {
            self.audioFiles.append(contentsOf: newAudioFiles)

            // If this is the first load, set up the first audio
            if self.currentIndex == nil && !self.audioFiles.isEmpty {
                self.playAtIndex(0, autoPlay: false)
            }

            // Hide loading indicator
            self.isLoadingFiles = false
            self.loadingProgress = 0
            self.loadingFileName = ""

            self.logger.info("✅ Added \(newAudioFiles.count) audio files to playlist")
        }

        // Process cover images for all files in background (lower priority)
        DispatchQueue.global(qos: .background).async {
            self.processSecondaryData(for: newAudioFiles)
        }

        // Start generating waveforms for all files in background
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.generateAllWaveforms()
        }
    }

    private func extractBasicMetadata(for audioFile: inout AudioFile) {
        // Only extract essential metadata - duration
        do {
            let player = try AVAudioPlayer(contentsOf: audioFile.url)
            audioFile.duration = player.duration
            audioFile.durationString = formatTime(player.duration)
        } catch {
            logger.error("❌ Failed to extract basic metadata: \(error.localizedDescription)")
            audioFile.duration = 0
            audioFile.durationString = "00:00"
        }
    }

    private func processSecondaryData(for audioFiles: [AudioFile]) {
        // Process cover images for all files (but don't block UI)
        logger.debug("🖼️ Starting to process cover images for \(audioFiles.count) files")

        for audioFile in audioFiles {
            autoreleasepool {
                // Only process if the file still exists in our array and doesn't have a cover yet
                if let index = self.audioFiles.firstIndex(where: { $0.id == audioFile.id }),
                    self.audioFiles[index].coverImage == nil {

                    let coverImage = self.extractCoverImage(from: audioFile.url)

                    DispatchQueue.main.async {
                        // Double-check the index is still valid (user might have deleted files)
                        if index < self.audioFiles.count &&
                            self.audioFiles[index].id == audioFile.id {
                            self.audioFiles[index].coverImage = coverImage
                            if coverImage != nil {
                                self.logger.debug("🖼️ Updated cover image for: \(audioFile.name)")
                            }
                        }
                    }
                }
            }
        }

        logger.debug("🖼️ Finished processing cover images")
    }

    // Enhanced waveform generation with preloading support and caching
    func generateWaveformIfNeeded(for index: Int, priority: DispatchQoS.QoSClass = .utility) {
        guard index < audioFiles.count else { return }
        let audioFile = audioFiles[index]

        // Skip if already generated or currently generating
        guard !audioFile.isWaveformGenerated && !audioFile.isProcessing else { return }

        // Mark as processing to prevent duplicate requests
        audioFiles[index].isProcessing = true

        // Generate waveform in background with configurable priority
        DispatchQueue.global(qos: priority).async {
            // First, try to load from cache
            var waveformData = self.loadCachedWaveformData(for: audioFile.url)

            if waveformData == nil {
                // Generate new waveform data if not in cache
                waveformData = self.generateWaveformData(from: audioFile.url)

                // Cache the generated data
                if let data = waveformData, !data.isEmpty {
                    self.saveCachedWaveformData(data, for: audioFile.url)
                }
            }

            DispatchQueue.main.async {
                // Ensure the index is still valid (user might have deleted files)
                if index < self.audioFiles.count && self.audioFiles[index].id == audioFile.id {
                    self.audioFiles[index].waveformData = waveformData ?? []
                    self.audioFiles[index].isWaveformGenerated = true
                    self.audioFiles[index].isProcessing = false
                    self.logger.debug("✅ Waveform ready for: \(audioFile.name)")
                }
            }
        }
    }

    // Conservative preload strategy - only preload next 1-2 tracks
    private func preloadNextTrackOnly(currentIndex: Int) {
        logger.info("🔄 Starting conservative preload for current index: \(currentIndex)")

        // Only preload next track with very low priority
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            if currentIndex + 1 < self.audioFiles.count {
                self.logger.debug("📝 Preloading next track at index \(currentIndex + 1)")
                self.generateWaveformIfNeeded(for: currentIndex + 1, priority: .background)

                // Optionally preload the track after next (with even more delay)
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3.0) {
                    if currentIndex + 2 < self.audioFiles.count {
                        self.logger.debug("📝 Preloading track after next at index \(currentIndex + 2)")
                        self.generateWaveformIfNeeded(for: currentIndex + 2, priority: .background)
                    }
                }
            }
        }
    }

    // Completely disable bulk waveform generation to prevent system overload
    func generateAllWaveforms() {
        logger.info("🚫 Bulk waveform generation disabled to prevent performance issues")
        // Only generate waveforms on-demand when tracks are played or preloaded
    }

    func playAtIndex(_ index: Int, autoPlay: Bool = true) {
        guard index < audioFiles.count else { return }

        // Stop all animations immediately using centralized manager
        PlayingIndicatorManager.shared.stopAllAnimations()

        let audio = audioFiles[index]
        logger.info("🎵 Loading audio at index \(index): \(audio.name)")

        // Set current index first to ensure UI consistency
        currentIndex = index
        currentAudioName = audio.name

        // Reset playback state to loading state
        isPlaying = false
        currentTime = 0
        currentTimeString = "00:00"

        // Stop timer and clear now playing info during transition
        stopTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        // Immediately generate waveform for current track to avoid delay
        generateWaveformIfNeeded(for: index, priority: .userInitiated)

        // Load cover image immediately for current song if not already loaded
        if audioFiles[index].coverImage == nil {
            loadCoverImageForCurrent(index: index)
        }

        // Move audio player setup to background to prevent main thread blocking
        DispatchQueue.global(qos: .userInitiated).async {
            // Stop current player if exists
            self.audioPlayer?.stop()

            // Setup new audio player
            self.setupAudioPlayer(with: audio.url)

            DispatchQueue.main.async {
                if autoPlay {
                    // Auto play after loading
                    self.audioPlayer?.play()
                    self.isPlaying = true
                    self.startTimer()
                    self.updateNowPlayingInfo()
                    self.logger.info("▶️ Auto-playing: \(audio.name)")
                } else {
                    // Loaded but not playing - ensure consistent state
                    self.isPlaying = false
                    self.duration = self.audioPlayer?.duration ?? 0
                    self.durationString = self.formatTime(self.duration)
                    self.updateNowPlayingInfo()
                    self.logger.info("⏸️ Loaded but not playing: \(audio.name)")
                }
            }
        }

        // Use conservative preload strategy for adjacent tracks only
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.preloadNextTrackOnly(currentIndex: index)
        }
    }

    // Load cover image immediately for currently playing song
    private func loadCoverImageForCurrent(index: Int) {
        guard index < audioFiles.count else { return }
        let audioFile = audioFiles[index]

        DispatchQueue.global(qos: .userInitiated).async {
            let coverImage = self.extractCoverImage(from: audioFile.url)

            DispatchQueue.main.async {
                // Ensure the index is still valid and the same audio file
                if index < self.audioFiles.count && self.audioFiles[index].id == audioFile.id {
                    self.audioFiles[index].coverImage = coverImage
                    self.logger.debug("🖼️ Loaded cover image for current song: \(audioFile.name)")
                }
            }
        }
    }

    private func setupAudioPlayer(with url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            // Update UI on main thread
            DispatchQueue.main.async {
                self.currentAudioName = url.lastPathComponent
                self.duration = self.audioPlayer?.duration ?? 0
                self.durationString = self.formatTime(self.duration)
                self.updateNowPlayingInfo()
            }

            logger.info("✅ Audio loaded successfully: \(url.lastPathComponent)")
        } catch {
            logger.error("❌ Audio loading failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.currentAudioName = "Audio loading failed"
            }
        }
    }

    func playPause() {
        guard let player = audioPlayer, let _ = currentIndex else {
            logger.warning("⚠️ Cannot play/pause: no audio player or current index")
            return
        }

        if isPlaying {
            // Pausing
            player.pause()
            stopTimer()
            isPlaying = false
            logger.info("⏸️ Audio paused")
        } else {
            // Playing
            player.play()
            startTimer()
            isPlaying = true
            logger.info("▶️ Audio resumed")
        }

        // Update now playing info in all cases
        updateNowPlayingInfo()
    }

    func stop() {
        // Stop all animations using centralized manager
        PlayingIndicatorManager.shared.stopAllAnimations()

        // Stop audio player and reset position
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0

        // Reset playback state
        currentTime = 0
        currentTimeString = "00:00"
        isPlaying = false

        // Stop timer and clear now playing info
        stopTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        logger.info("⏹️ Audio stopped")
    }

    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
        currentTimeString = formatTime(time)
        updateNowPlayingInfo()
    }

    func playPrevious() {
        if let index = currentIndex, index > 0 {
            playAtIndex(index - 1, autoPlay: true)  // Previous/Next: auto-play
        }
    }

    func playNext() {
        guard let index = currentIndex else { return }

        switch repeatMode {
        case .single:
            // Single repeat: replay current song
            playAtIndex(index, autoPlay: true)
            logger.info("🔂 Single repeat: replaying current song")
        case .playlist:
            // Playlist repeat: go to next song, or back to first song if at end
            if index < audioFiles.count - 1 {
                playAtIndex(index + 1, autoPlay: true)
            } else {
                playAtIndex(0, autoPlay: true)  // Back to first song
                logger.info("🔁 Playlist repeat: back to first song")
            }
        case .none:
            // No repeat: go to next song or stop if at end
            if index < audioFiles.count - 1 {
                playAtIndex(index + 1, autoPlay: true)
            } else {
                stop()
                logger.info("⏹️ End of playlist: stopping")
            }
        }
    }

    func removeAudio(at offsets: IndexSet) {
        let removedIndices = offsets.map { $0 }
        audioFiles.remove(atOffsets: offsets)
        if let current = currentIndex, removedIndices.contains(current) {
            stop()
            currentIndex = nil
            currentAudioName = "No audio selected"
        } else if let current = currentIndex, current >= audioFiles.count {
            currentIndex = audioFiles.count - 1
        }
    }

    func moveAudio(from source: IndexSet, to destination: Int) {
        // Save the currently playing audio ID for relocation after moving
        var currentlyPlayingAudioId: UUID? = nil
        if let current = currentIndex {
            currentlyPlayingAudioId = audioFiles[current].id
        }

        // Execute move operation
        audioFiles.move(fromOffsets: source, toOffset: destination)

        // Re-find the new index of currently playing audio
        if let playingId = currentlyPlayingAudioId {
            currentIndex = audioFiles.firstIndex(where: { $0.id == playingId })
        }

    }

    // Simplified drag move method
    func moveAudioFromTo(from sourceIndex: Int, to targetIndex: Int) {
        logger.debug("🔄 Attempting move: from index \(sourceIndex) to index \(targetIndex)")

        guard sourceIndex != targetIndex,
                sourceIndex >= 0, sourceIndex < audioFiles.count,
                targetIndex >= 0, targetIndex < audioFiles.count else {
            logger.info("❌ Move blocked: invalid or same indices")
            return
        }

        // Save currently playing audio ID
        var currentlyPlayingAudioId: UUID? = nil
        if let current = currentIndex {
            currentlyPlayingAudioId = audioFiles[current].id
        }

        // Move element
        let movingAudio = audioFiles[sourceIndex]
        logger.info("📦 Moving audio: \(movingAudio.name)")

        audioFiles.remove(at: sourceIndex)

        // Adjust target index (if source index is before target index, target index needs to be reduced by 1)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        audioFiles.insert(movingAudio, at: adjustedTargetIndex)

        logger.info("✅ Move completed: \(movingAudio.name) is now at index \(adjustedTargetIndex)")

        // Re-find the new index of currently playing audio
        if let playingId = currentlyPlayingAudioId {
            currentIndex = audioFiles.firstIndex(where: { $0.id == playingId })
        }

    }

    // Move up one position
    func moveAudioUp(from index: Int) {
        guard index > 0 && index < audioFiles.count else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.insert(movingAudio, at: index - 1)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: index - 1)
    }

    // Move down one position
    func moveAudioDown(from index: Int) {
        guard index >= 0 && index < audioFiles.count - 1 else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.insert(movingAudio, at: index + 1)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: index + 1)
    }

    // Move to top
    func moveAudioToTop(from index: Int) {
        guard index > 0 && index < audioFiles.count else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.insert(movingAudio, at: 0)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: 0)
    }

    // Move to bottom
    func moveAudioToBottom(from index: Int) {
        guard index >= 0 && index < audioFiles.count - 1 else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.append(movingAudio)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: audioFiles.count - 1)
    }

    // Helper method: update current playing index
    private func updateCurrentIndexAfterMove(originalIndex: Int, newIndex: Int) {
        guard let current = currentIndex else { return }

        if current == originalIndex {
            // The moved song is currently playing
            currentIndex = newIndex
        } else if originalIndex < current && newIndex >= current {
            // Song moved from front to current or back, current index needs to decrease by 1
            currentIndex = current - 1
        } else if originalIndex > current && newIndex <= current {
            // Song moved from back to current or front, current index needs to increase by 1
            currentIndex = current + 1
        }
        // Other cases: current index remains unchanged
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }

            let newTime = player.currentTime
            let newTimeString = self.formatTime(newTime)

            // Only update if values actually changed to reduce UI updates
            if abs(self.currentTime - newTime) > 0.1 {
                self.currentTime = newTime
                self.currentTimeString = newTimeString

                // Update now playing info less frequently (every 4 seconds)
                if Int(newTime) % 4 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Toggle repeat mode
    func toggleRepeatMode() {
        switch repeatMode {
        case .none:
            repeatMode = .single
        case .single:
            repeatMode = .playlist
        case .playlist:
            repeatMode = .none
        }
        logger.info("🔄 Repeat mode changed to: \(self.repeatMode.description)")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("🎵 Audio finished playing, successfully: \(flag)")

        if flag {
            // Stop all animations before transitioning to next track
            PlayingIndicatorManager.shared.stopAllAnimations()

            // Add a small delay to ensure smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.playNext()
            }
        } else {
            // Handle playback failure
            logger.error("❌ Audio playback failed")
            DispatchQueue.main.async {
                self.isPlaying = false
                self.stopTimer()
                self.updateNowPlayingInfo()
            }
        }
    }

    // Extract cover image from audio file
    private func extractCoverImage(from url: URL) -> NSImage? {
        do {
            let asset = AVURLAsset(url: url)

            // Try to get artwork from metadata
            let metadataItems = asset.commonMetadata
            for metadataItem in metadataItems {
                if metadataItem.commonKey == .commonKeyArtwork {
                    // Try different data formats
                    if let data = metadataItem.value as? Data,
                       let image = NSImage(data: data) {
                        logger.debug("🖼️ Successfully extracted cover image for: \(url.lastPathComponent)")
                        return image
                    }

                    // Try NSData format (for older files)
                    if let nsData = metadataItem.value as? NSData,
                       let image = NSImage(data: nsData as Data) {
                        logger.debug("🖼️ Successfully extracted cover image (NSData) for: \(url.lastPathComponent)")
                        return image
                    }

                    // Try dictionary format (for some file types)
                    if let dict = metadataItem.value as? [String: Any],
                       let imageData = dict["data"] as? Data,
                       let image = NSImage(data: imageData) {
                        logger.debug("🖼️ Successfully extracted cover image (dict) for: \(url.lastPathComponent)")
                        return image
                    }
                }
            }

            // Try alternative metadata keys
            for metadataItem in metadataItems {
                if let commonKey = metadataItem.commonKey,
                   commonKey.rawValue.lowercased().contains("artwork") ||
                   commonKey.rawValue.lowercased().contains("picture") {
                    if let data = metadataItem.value as? Data,
                       let image = NSImage(data: data) {
                        logger.debug("🖼️ Found cover via alternative key for: \(url.lastPathComponent)")
                        return image
                    }
                }
            }

            logger.debug("🖼️ No cover image found for: \(url.lastPathComponent)")
            return nil

        } catch {
            logger.error("❌ Error extracting cover image: \(error.localizedDescription)")
            return nil
        }
    }

    // Optimized waveform generation with memory management
    private func generateWaveformData(from url: URL) -> [Float] {
        return autoreleasepool {
            logger.debug("🌊 Generating waveform data for: \(url.lastPathComponent)")

            guard let audioFile = try? AVAudioFile(forReading: url) else {
                logger.error("❌ Failed to read audio file for waveform: \(url.lastPathComponent)")
                return []
            }

            let format = audioFile.processingFormat
            let totalFrames = audioFile.length
            let sampleCount = 400 // Number of waveform bars to generate

            // Calculate chunk size for streaming (process in smaller chunks)
            let maxChunkSize: AVAudioFrameCount = 4096 * 8 // 32KB chunks
            let samplesPerBar = max(1, Int(totalFrames) / sampleCount)

            var waveformData: [Float] = []
            waveformData.reserveCapacity(sampleCount) // Pre-allocate for performance

            // Process audio in chunks to manage memory
            var processedFrames: AVAudioFramePosition = 0
            var currentBarIndex = 0
            var currentBarMax: Float = 0
            var framesInCurrentBar = 0

            while processedFrames < totalFrames && currentBarIndex < sampleCount {
                autoreleasepool {
                    // Calculate chunk size for this iteration
                    let remainingFrames = totalFrames - processedFrames
                    let chunkSize = min(maxChunkSize, AVAudioFrameCount(remainingFrames))

                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
                        logger.error("❌ Failed to create chunk buffer")
                        return
                    }

                    do {
                        audioFile.framePosition = processedFrames
                        try audioFile.read(into: buffer)
                    } catch {
                        logger.error("❌ Failed to read chunk: \(error.localizedDescription)")
                        return
                    }

                    guard let channelData = buffer.floatChannelData?[0] else {
                        logger.error("❌ No channel data in chunk")
                        return
                    }

                    let frameLength = Int(buffer.frameLength)

                    // Process samples in this chunk
                    for i in 0..<frameLength {
                        let amplitude = abs(channelData[i])
                        currentBarMax = max(currentBarMax, amplitude)
                        framesInCurrentBar += 1

                        // Check if we've collected enough samples for current bar
                        if framesInCurrentBar >= samplesPerBar {
                            // Normalize and add to waveform data
                            let normalizedAmplitude = min(max(currentBarMax, 0.1), 1.0)
                            waveformData.append(normalizedAmplitude)

                            // Reset for next bar
                            currentBarIndex += 1
                            currentBarMax = 0
                            framesInCurrentBar = 0

                            // Exit early if we have enough bars
                            if currentBarIndex >= sampleCount {
                                break
                            }
                        }
                    }

                    processedFrames += AVAudioFramePosition(frameLength)
                }
            }

            // Handle any remaining partial bar
            if currentBarIndex < sampleCount && framesInCurrentBar > 0 {
                let normalizedAmplitude = min(max(currentBarMax, 0.1), 1.0)
                waveformData.append(normalizedAmplitude)
                currentBarIndex += 1
            }

            // Fill any remaining bars with minimal values if needed
            while waveformData.count < sampleCount {
                waveformData.append(0.1)
            }

            logger.info("✅ Generated optimized waveform data with \(waveformData.count) points for: \(url.lastPathComponent)")
            return waveformData
        }
    }

    // Extract audio format information
    private func extractAudioFormatInfo(for audioFile: AudioFile) -> AudioFile {
        var updatedAudio = audioFile

        do {
            let asset = AVURLAsset(url: audioFile.url)

            // Get audio tracks
            let audioTracks = asset.tracks(withMediaType: .audio)
            guard let audioTrack = audioTracks.first else {
                logger.error("❌ No audio tracks found in: \(audioFile.name)")
                return updatedAudio
            }

            // Get format descriptions
            let formatDescriptions = audioTrack.formatDescriptions
            guard let formatDescription = formatDescriptions.first else {
                logger.error("❌ No format description found in: \(audioFile.name)")
                return updatedAudio
            }

            // Extract basic format info from Core Media
            let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription as! CMAudioFormatDescription)

            if let basicDesc = basicDescription?.pointee {
                // Sample rate
                updatedAudio.sampleRate = String(format: "%.0f Hz", basicDesc.mSampleRate)

                // Channels
                let channelCount = basicDesc.mChannelsPerFrame
                if channelCount == 1 {
                    updatedAudio.channels = "mono"
                } else if channelCount == 2 {
                    updatedAudio.channels = "stereo"
                } else {
                    updatedAudio.channels = "\(channelCount)ch"
                }

                // Bit depth
                let bitsPerChannel = basicDesc.mBitsPerChannel
                if bitsPerChannel > 0 {
                    updatedAudio.bitDepth = "\(bitsPerChannel) bit"
                } else {
                    updatedAudio.bitDepth = "压缩格式"
                }

                // Format ID to codec mapping
                let formatID = basicDesc.mFormatID
                switch formatID {
                case kAudioFormatLinearPCM:
                    updatedAudio.codec = "PCM"
                case kAudioFormatMPEGLayer3:
                    updatedAudio.codec = "MP3"
                case kAudioFormatMPEG4AAC:
                    updatedAudio.codec = "AAC"
                case kAudioFormatAppleLossless:
                    updatedAudio.codec = "ALAC"
                case kAudioFormatFLAC:
                    updatedAudio.codec = "FLAC"
                default:
                    // Convert FourCharCode to string
                    let fourCC = String(format: "%c%c%c%c",
                                      (formatID >> 24) & 255,
                                      (formatID >> 16) & 255,
                                      (formatID >> 8) & 255,
                                      formatID & 255)
                    updatedAudio.codec = fourCC
                }
            }

            // File extension to format
            let fileExtension = audioFile.url.pathExtension.lowercased()
            switch fileExtension {
            case "mp3":
                updatedAudio.format = "MP3"
            case "wav":
                updatedAudio.format = "WAV"
            case "aac", "m4a":
                updatedAudio.format = "AAC/M4A"
            case "flac":
                updatedAudio.format = "FLAC"
            case "aiff", "aif":
                updatedAudio.format = "AIFF"
            case "ogg":
                updatedAudio.format = "OGG"
            case "wma":
                updatedAudio.format = "WMA"
            default:
                updatedAudio.format = fileExtension.uppercased()
            }

            // Estimate bit rate for compressed formats
            if let basicDesc = basicDescription?.pointee {
                let duration = updatedAudio.duration
                if duration > 0 {
                    // Get file size
                    if let fileSize = try? audioFile.url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        let fileSizeInBits = Double(fileSize) * 8
                        let estimatedBitRate = fileSizeInBits / duration / 1000 // kbps

                        // For compressed formats, assume CBR for common bitrates, otherwise VBR
                        if basicDesc.mFormatID == kAudioFormatLinearPCM {
                            let theoreticalBitRate = basicDesc.mSampleRate * Double(basicDesc.mChannelsPerFrame) * Double(basicDesc.mBitsPerChannel) / 1000
                            updatedAudio.bitRate = String(format: "%.0fkbps", theoreticalBitRate)
                        } else {
                            let roundedBitRate = round(estimatedBitRate)
                            // Check if it's a common CBR bitrate
                            let commonCBRRates: [Double] = [64, 96, 128, 160, 192, 224, 256, 320]
                            if commonCBRRates.contains(roundedBitRate) {
                                updatedAudio.bitRate = "CBR \(Int(roundedBitRate))kbps"
                            } else {
                                updatedAudio.bitRate = "VBR ~\(Int(roundedBitRate))kbps"
                            }
                        }
                    } else {
                        // Calculate theoretical bitrate for uncompressed formats
                        if basicDesc.mFormatID == kAudioFormatLinearPCM {
                            let theoreticalBitRate = basicDesc.mSampleRate * Double(basicDesc.mChannelsPerFrame) * Double(basicDesc.mBitsPerChannel) / 1000
                            updatedAudio.bitRate = String(format: "%.0fkbps", theoreticalBitRate)
                        } else {
                            updatedAudio.bitRate = "VBR"
                        }
                    }
                }
            }

            logger.info("📊 Audio format info extracted for: \(audioFile.name)")
            logger.debug("   Format: \(updatedAudio.format), Codec: \(updatedAudio.codec)")
            logger.debug("   Sample Rate: \(updatedAudio.sampleRate), Channels: \(updatedAudio.channels)")
            logger.debug("   Bit Depth: \(updatedAudio.bitDepth), Bit Rate: \(updatedAudio.bitRate)")

        } catch {
            logger.error("❌ Failed to extract audio format info: \(error.localizedDescription)")
        }

        return updatedAudio
    }
}

// View extension for conditional modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Centralized animation manager to prevent multiple timer instances
class PlayingIndicatorManager: ObservableObject {
    static let shared = PlayingIndicatorManager()

    @Published var animationValues = [0.2, 0.4, 0.8, 0.6, 0.3]
    @Published var activeTrackId: UUID? = nil

    private var timer: Timer?
    private let animationQueue = DispatchQueue(label: "PlayingIndicatorManager.animation")

    private init() {}

    func startAnimation(for trackId: UUID) {
        animationQueue.async { [weak self] in
            self?.stopAnimation()
            self?.activeTrackId = trackId

            DispatchQueue.main.async {
                self?.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    guard self?.activeTrackId == trackId else {
                        self?.stopAnimation()
                        return
                    }

                    withAnimation {
                        self?.animationValues = (0..<5).map { _ in Double.random(in: 0.2...1.0) }
                    }
                }
            }
        }
    }

    func stopAnimation() {
        activeTrackId = nil
        timer?.invalidate()
        timer = nil
    }

    func stopAllAnimations() {
        stopAnimation()
    }
}

// Simplified playing indicator using centralized state
struct PlayingIndicator: View {
    let trackId: UUID
    @StateObject private var manager = PlayingIndicatorManager.shared

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: CGFloat(manager.animationValues[index]) * 16)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 0.3...0.8))
                            .delay(Double(index) * 0.1),
                        value: manager.animationValues[index]
                    )
            }
        }
        .onAppear {
            manager.startAnimation(for: trackId)
        }
        .onDisappear {
            if manager.activeTrackId == trackId {
                manager.stopAnimation()
            }
        }
    }
}

// Waveform view component
struct WaveformView: View {
    let waveformData: [Float]
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var dragLocation: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !waveformData.isEmpty else { return }

                let width = size.width
                let height = size.height
                let barWidth = max(1.0, width / CGFloat(waveformData.count))
                let progress = CGFloat(currentTime / duration)

                for (index, amplitude) in waveformData.enumerated() {
                    let x = CGFloat(index) * barWidth
                    let barHeight = CGFloat(amplitude) * height * 0.8
                    let y = (height - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth - 0.5, height: barHeight)

                    // Determine color based on progress
                    let color: Color = x <= progress * width ? .accentColor : .secondary.opacity(0.5)

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 4),
                        with: .color(color)
                    )
                }

                // Draw progress line
                let progressX = progress * width
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: progressX, y: 0))
                        path.addLine(to: CGPoint(x: progressX, y: height))
                    },
                    with: .color(.accentColor),
                    lineWidth: 2
                )
            }
            .background(Color.clear)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragLocation = value.location.x
                        let progress = min(max(0, dragLocation / geometry.size.width), 1)
                        let newTime = progress * duration
                        currentTime = newTime
                    }
                    .onEnded { value in
                        isDragging = false
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        let newTime = progress * duration
                        onSeek(newTime)
                    }
            )
            .onTapGesture { location in
                let progress = min(max(0, location.x / geometry.size.width), 1)
                let newTime = progress * duration
                onSeek(newTime)
            }
        }
        .frame(height: 60)
        .cornerRadius(4)
    }
}

// Empty waveform view component for when no audio is loaded
struct EmptyWaveformView: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let barCount = 400 // Same as WaveformView for consistency
                let barWidth = max(1.0, width / CGFloat(barCount))
                let progress = duration > 0 ? CGFloat(currentTime / duration) : 0

                for i in 0..<barCount {
                    let x = CGFloat(i) * barWidth
                    // Generate pseudo-random heights based on index for consistent pattern
                    let randomSeed = sin(Double(i) * 0.1) * cos(Double(i) * 0.05)
                    let normalizedHeight = (randomSeed + 1.0) / 2.0 // Normalize to 0-1
                    let barHeight = CGFloat(normalizedHeight) * height * 0.3 + height * 0.1 // Smaller bars for empty state
                    let y = (height - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth - 0.5, height: barHeight)

                    // Determine color based on progress
                    let color: Color = x <= progress * width ? .accentColor.opacity(0.6) : .secondary.opacity(0.2)

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 4),
                        with: .color(color)
                    )
                }

                // Draw progress line if there's valid duration
                if duration > 0 {
                    let progressX = progress * width
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: progressX, y: 0))
                            path.addLine(to: CGPoint(x: progressX, y: height))
                        },
                        with: .color(.accentColor.opacity(0.6)),
                        lineWidth: 2
                    )
                }
            }
            .background(Color.clear)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if duration > 0 {
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            currentTime = newTime
                        }
                    }
                    .onEnded { value in
                        if duration > 0 {
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            onSeek(newTime)
                        }
                    }
            )
            .onTapGesture { location in
                if duration > 0 {
                    let progress = min(max(0, location.x / geometry.size.width), 1)
                    let newTime = progress * duration
                    onSeek(newTime)
                }
            }
        }
        .frame(height: 60)
        .cornerRadius(4)
        .overlay(
            // Add a subtle label when no audio is loaded
            Group {
                if duration == 0 {
                    Text("No audio loaded")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .blur(radius: 2)
                        )
                }
            }
        )
    }
}

// Loading waveform view component with animated shimmer effect
struct LoadingWaveformView: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var animationPhase: Double = 0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let barCount = 400
                let barWidth = max(1.0, width / CGFloat(barCount))
                let progress = duration > 0 ? CGFloat(currentTime / duration) : 0

                for i in 0..<barCount {
                    let x = CGFloat(i) * barWidth
                    // Create shimmer effect with sine wave
                    let shimmerOffset = sin(animationPhase + Double(i) * 0.1) * 0.3 + 0.5
                    let baseHeight = sin(Double(i) * 0.05) * 0.2 + 0.3
                    let barHeight = CGFloat(baseHeight + shimmerOffset * 0.2) * height * 0.6
                    let y = (height - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth - 0.5, height: barHeight)

                    // Animated shimmer colors
                    let shimmerIntensity = Float(shimmerOffset)
                    let color: Color = x <= progress * width ?
                        .accentColor.opacity(0.4 + Double(shimmerIntensity) * 0.4) :
                        .secondary.opacity(0.2 + Double(shimmerIntensity) * 0.2)

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 4),
                        with: .color(color)
                    )
                }

                // Progress line
                if duration > 0 {
                    let progressX = progress * width
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: progressX, y: 0))
                            path.addLine(to: CGPoint(x: progressX, y: height))
                        },
                        with: .color(.accentColor.opacity(0.7)),
                        lineWidth: 2
                    )
                }
            }
            .background(Color.clear)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if duration > 0 {
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            currentTime = newTime
                        }
                    }
                    .onEnded { value in
                        if duration > 0 {
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            onSeek(newTime)
                        }
                    }
            )
            .onTapGesture { location in
                if duration > 0 {
                    let progress = min(max(0, location.x / geometry.size.width), 1)
                    let newTime = progress * duration
                    onSeek(newTime)
                }
            }
        }
        .frame(height: 60)
        .cornerRadius(4)
        .overlay(
            Text("Generating waveform...")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .blur(radius: 2)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animationPhase = .pi * 2
            }
        }
    }
}

// Placeholder waveform view component with subtle animation
struct PlaceholderWaveformView: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var pulsePhase: Double = 0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let barCount = 400
                let barWidth = max(1.0, width / CGFloat(barCount))
                let progress = duration > 0 ? CGFloat(currentTime / duration) : 0

                for i in 0..<barCount {
                    let x = CGFloat(i) * barWidth
                    // Simple static pattern with subtle pulse
                    let basePattern = sin(Double(i) * 0.08) * 0.15 + 0.25
                    let pulseEffect = sin(pulsePhase) * 0.1 + 1.0
                    let barHeight = CGFloat(basePattern * pulseEffect) * height * 0.4
                    let y = (height - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth - 0.5, height: barHeight)

                    let color: Color = x <= progress * width ?
                        .accentColor.opacity(0.3) :
                        .secondary.opacity(0.15)

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 4),
                        with: .color(color)
                    )
                }

                // Progress line
                if duration > 0 {
                    let progressX = progress * width
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: progressX, y: 0))
                            path.addLine(to: CGPoint(x: progressX, y: height))
                        },
                        with: .color(.accentColor.opacity(0.5)),
                        lineWidth: 2
                    )
                }
            }
            .background(Color.clear)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if duration > 0 {
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            currentTime = newTime
                        }
                    }
                    .onEnded { value in
                        if duration > 0 {
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            onSeek(newTime)
                        }
                    }
            )
            .onTapGesture { location in
                if duration > 0 {
                    let progress = min(max(0, location.x / geometry.size.width), 1)
                    let newTime = progress * duration
                    onSeek(newTime)
                }
            }
        }
        .frame(height: 60)
        .cornerRadius(4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = .pi
            }
        }
    }
}

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        AudioPlayerView()
    }
}

// Optimized audio row component for better list performance
struct AudioRowView: View {
    let audio: AudioFile
    let index: Int
    let isEditMode: Bool
    let isSelected: Bool
    let isCurrentlyPlaying: Bool
    let isCurrentTrack: Bool
    let onSelectionToggle: () -> Void
    let onPlayAction: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onMoveToTop: () -> Void
    let onMoveToBottom: () -> Void
    let onRemove: () -> Void
    let playerViewModel: AudioPlayerViewModel

    private let logger = Logger(subsystem: "com.mplayer.audioPlayer", category: "AudioRowView")

    var body: some View {
        HStack {
            // Selection indicator (only shown in edit mode)
            if isEditMode {
                Button(action: onSelectionToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.system(size: 20, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 30)
            }

            // Drag indicator (only shown in edit mode)
            if isEditMode {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .help("Drag to reorder")
            }

            // Play index number
            Text("\(index + 1)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 25, alignment: .trailing)

            // Play status indicator
            Group {
                if isCurrentlyPlaying {
                    PlayingIndicator(trackId: audio.id)
                        .frame(width: 20, height: 16)
                } else if isCurrentTrack {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 20, height: 16)
                } else {
                    Spacer()
                        .frame(width: 20, height: 16)
                }
            }

            Text(audio.name)
                .font(.system(size: 14))
                .foregroundColor(isCurrentTrack ? .accentColor : .primary)

            Spacer()

            Text(audio.durationString)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEditMode ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .if(isEditMode) { view in
            view.onTapGesture {
                onSelectionToggle()
            }
        }
        .if(!isEditMode) { view in
            view.onTapGesture(count: 2) {
                onPlayAction()
            }
        }
        .contextMenu {
            Button("Move Up") {
                onMoveUp()
            }
            .disabled(index == 0)

            Button("Move Down") {
                onMoveDown()
            }
            .disabled(index == playerViewModel.audioFiles.count - 1)

            Divider()

            Button("Move to Top") {
                onMoveToTop()
            }
            .disabled(index == 0)

            Button("Move to Bottom") {
                onMoveToBottom()
            }
            .disabled(index == playerViewModel.audioFiles.count - 1)

            Divider()

            Button("Remove from List", role: .destructive) {
                onRemove()
            }
        }
        .if(isEditMode) { view in
            view.draggable(audio.id.uuidString) {
                // Drag preview
                HStack {
                    Image(systemName: "music.note")
                    Text(audio.name)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(8)
            }
            .dropDestination(for: String.self) { items, location in
                logger.debug("🎯 Drop triggered: item count \(items.count)")

                // Only handle drag and drop in edit mode
                guard isEditMode,
                        let draggedIdString = items.first,
                        let draggedId = UUID(uuidString: draggedIdString),
                        draggedId != audio.id else {
                    logger.info("❌ Drop rejected: edit mode=\(isEditMode), valid ID=\(items.first != nil)")
                    return false
                }

                logger.debug("🔍 Drag ID: \(draggedIdString), target audio: \(audio.name)")

                // Find source and target indices
                guard let sourceIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == draggedId }),
                      let targetIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) else {
                    logger.error("❌ Indices not found")
                    return false
                }

                logger.info("📍 Source index: \(sourceIndex), target index: \(targetIndex)")

                // Call simple move method directly
                withAnimation(.easeInOut(duration: 0.3)) {
                    playerViewModel.moveAudioFromTo(from: sourceIndex, to: targetIndex)
                }

                return true
            } isTargeted: { isTargeted in
                if isTargeted {
                    logger.debug("🎯 Drag hovering over: \(audio.name)")
                }
            }
        }
    }
}
