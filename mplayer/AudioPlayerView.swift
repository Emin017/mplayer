//
//  AudioPlayerView.swift
//  mplayer
//
//  Created by Emin (Qiming Chu) on 2025/9/3.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import os.log
import AVKit

// Logger instance
private let logger = Logger(subsystem: "com.mplayer.audioPlayer", category: "AudioPlayerView")

// Audio file data structure
struct AudioFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    var duration: Double = 0
    var durationString: String = "00:00"
    var coverImage: NSImage? = nil
}

struct AudioPlayerView: View {
    @StateObject private var playerViewModel = AudioPlayerViewModel()
    @State private var isEditMode: Bool = false

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
                }
                .padding(.horizontal)

                // Progress bar
                HStack {
                    Text(playerViewModel.currentTimeString)
                        .font(.system(size: 14))
                        .monospacedDigit()

                    Slider(value: $playerViewModel.currentTime, in: 0...playerViewModel.duration, onEditingChanged: { editing in
                        if !editing {
                            playerViewModel.seek(to: playerViewModel.currentTime)
                        }
                    })

                    Text(playerViewModel.durationString)
                        .font(.system(size: 14))
                        .monospacedDigit()
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
                    .disabled(playerViewModel.currentIndex == nil || playerViewModel.currentIndex == playerViewModel.audioFiles.count - 1)

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

            // Playlist area
            VStack(alignment: .leading, spacing: 10) {
                // Playlist title
                HStack {
                    Text("Playlist")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()

                    // Edit mode toggle button
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditMode.toggle()
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
                    ForEach(Array(playerViewModel.audioFiles.enumerated()), id: \.element.id) { index, audio in
                        HStack {
                            // Drag indicator (only shown in edit mode)
                            if isEditMode {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 20)
                                    .help("Drag to reorder") // macOS tooltip text
                            }

                            // Play index number
                            Text("\(index + 1)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 25, alignment: .trailing)

                            // Play status indicator
                            Group {
                                if let currentIndex = playerViewModel.currentIndex,
                                    playerViewModel.audioFiles[currentIndex].id == audio.id && playerViewModel.isPlaying {
                                    // Dynamic playing indicator
                                    PlayingIndicator()
                                        .frame(width: 20, height: 16)
                                } else if let currentIndex = playerViewModel.currentIndex,
                                        playerViewModel.audioFiles[currentIndex].id == audio.id {
                                    // Pause status indicator
                                    Image(systemName: "pause.fill")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 20, height: 16)
                                } else {
                                    // Empty placeholder
                                    Spacer()
                                        .frame(width: 20, height: 16)
                                }
                            }

                            Text(audio.name)
                                .font(.system(size: 14))
                                .foregroundColor(playerViewModel.currentIndex != nil && playerViewModel.audioFiles[playerViewModel.currentIndex!].id == audio.id ? .accentColor : .primary)
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
                        .onTapGesture(count: 2) {
                            if !isEditMode {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.playAtIndex(actualIndex)
                                }
                            }
                        }
                        .contextMenu {
                            Button("Move Up") {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioUp(from: actualIndex)
                                }
                            }
                            .disabled(index == 0)

                            Button("Move Down") {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioDown(from: actualIndex)
                                }
                            }
                            .disabled(index == playerViewModel.audioFiles.count - 1)

                            Divider()

                            Button("Move to Top") {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioToTop(from: actualIndex)
                                }
                            }
                            .disabled(index == 0)

                            Button("Move to Bottom") {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.moveAudioToBottom(from: actualIndex)
                                }
                            }
                            .disabled(index == playerViewModel.audioFiles.count - 1)

                            Divider()

                            Button("Remove from List", role: .destructive) {
                                if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                    playerViewModel.removeAudio(at: IndexSet([actualIndex]))
                                }
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

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    // Logger instance
    private let logger = Logger(subsystem: "com.mplayer.audioPlayer", category: "AudioPlayerViewModel")

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAudioDidFinishPlaying() {
        playNext()
    }

    func selectAudioFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.mp3, UTType.wav, UTType.mpeg4Audio, UTType.aiff]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            logger.info("📁 Selected \(urls.count) audio files")
            for url in urls {
                if !audioFiles.contains(where: { $0.url == url }) {
                    var newAudio = AudioFile(url: url, name: url.lastPathComponent)
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        newAudio.duration = player.duration
                        newAudio.durationString = formatTime(player.duration)
                    }
                    // Extract cover image
                    newAudio.coverImage = extractCoverImage(from: url)
                    audioFiles.append(newAudio)
                    logger.debug("➕ Added audio file: \(newAudio.name)")
                } else {
                    logger.debug("⚠️ Skipped duplicate file: \(url.lastPathComponent)")
                }
            }
            if currentIndex == nil && !audioFiles.isEmpty {
                playAtIndex(0)
            }
        } else {
            logger.debug("❌ Audio file selection cancelled")
        }
        objectWillChange.send()
    }

    func playAtIndex(_ index: Int) {
        stop()
        currentIndex = index
        let audio = audioFiles[index]
        logger.info("🎵 Playing audio at index \(index): \(audio.name)")
        setupAudioPlayer(with: audio.url)
        // Auto play after loading
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    private func setupAudioPlayer(with url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            currentAudioName = url.lastPathComponent
            duration = audioPlayer?.duration ?? 0
            durationString = formatTime(duration)
            logger.info("✅ Audio loaded successfully: \(url.lastPathComponent)")
        } catch {
            logger.error("❌ Audio loading failed: \(error.localizedDescription)")
            currentAudioName = "Audio loading failed"
        }
        objectWillChange.send()
    }

    func playPause() {
        guard let player = audioPlayer, let _ = currentIndex else { return }
        if isPlaying {
            player.pause()
            stopTimer()
            logger.info("⏸️ Audio paused")
        } else {
            player.play()
            startTimer()
            logger.info("▶️ Audio resumed")
        }
        isPlaying.toggle()
        objectWillChange.send()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        currentTimeString = "00:00"
        stopTimer()
        isPlaying = false
        logger.info("⏹️ Audio stopped")
        objectWillChange.send()
    }

    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
        currentTimeString = formatTime(time)
        objectWillChange.send()
    }

    func playPrevious() {
        if let index = currentIndex, index > 0 {
            playAtIndex(index - 1)
        }
        objectWillChange.send()
    }

    func playNext() {
        if let index = currentIndex, index < audioFiles.count - 1 {
            playAtIndex(index + 1)
        } else {
            stop()
        }
        objectWillChange.send()
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
        objectWillChange.send()
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

        objectWillChange.send()
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

        objectWillChange.send()
    }

    // Move up one position
    func moveAudioUp(from index: Int) {
        guard index > 0 && index < audioFiles.count else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.insert(movingAudio, at: index - 1)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: index - 1)
        objectWillChange.send()
    }

    // Move down one position
    func moveAudioDown(from index: Int) {
        guard index >= 0 && index < audioFiles.count - 1 else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.insert(movingAudio, at: index + 1)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: index + 1)
        objectWillChange.send()
    }

    // Move to top
    func moveAudioToTop(from index: Int) {
        guard index > 0 && index < audioFiles.count else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.insert(movingAudio, at: 0)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: 0)
        objectWillChange.send()
    }

    // Move to bottom
    func moveAudioToBottom(from index: Int) {
        guard index >= 0 && index < audioFiles.count - 1 else { return }

        let movingAudio = audioFiles[index]
        audioFiles.remove(at: index)
        audioFiles.append(movingAudio)

        // Update current playing index
        updateCurrentIndexAfterMove(originalIndex: index, newIndex: audioFiles.count - 1)
        objectWillChange.send()
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.currentTimeString = self.formatTime(player.currentTime)
            self.objectWillChange.send()
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

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playNext()
        }
    }

    // Extract cover image from audio file
    private func extractCoverImage(from url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)

        // Try to get artwork from metadata
        let metadataItems = asset.commonMetadata
        for metadataItem in metadataItems {
            if metadataItem.commonKey == .commonKeyArtwork,
               let data = metadataItem.value as? Data {
                return NSImage(data: data)
            }
        }

        logger.debug("🖼️ No cover image found for: \(url.lastPathComponent)")
        return nil
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

// Dynamic playing indicator component
struct PlayingIndicator: View {
    @State private var animationValues = [0.2, 0.4, 0.8, 0.6, 0.3]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: CGFloat(animationValues[index]) * 16)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 0.3...0.8))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animationValues[index]
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                for i in 0..<animationValues.count {
                    animationValues[i] = Double.random(in: 0.2...1.0)
                }
            }
        }
    }
}

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        AudioPlayerView()
    }
}
