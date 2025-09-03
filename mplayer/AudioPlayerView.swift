//
//  AudioPlayerView.swift
//  mplayer
//
//  Created by Emin (Qiming Chu) on 2025/9/3.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// Audio file data structure
struct AudioFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    var duration: Double = 0
    var durationString: String = "00:00"
}

struct AudioPlayerView: View {
    @StateObject private var playerViewModel = AudioPlayerViewModel()

    var body: some View {
        VStack(spacing: 15) {
            // Top playback control area
            VStack(spacing: 15) {
                // Current audio info and title
                HStack {
                    Text("Audio Player")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(playerViewModel.currentAudioName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
                    Button("添加音频") {
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
                    Text("播放列表")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(playerViewModel.audioFiles.count) 首歌曲")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Playlist
                List {
                    ForEach(Array(playerViewModel.audioFiles.enumerated()), id: \.element.id) { index, audio in
                        HStack {
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
                        .onTapGesture {
                            if let actualIndex = playerViewModel.audioFiles.firstIndex(where: { $0.id == audio.id }) {
                                playerViewModel.playAtIndex(actualIndex)
                            }
                        }
                    }
                    .onDelete(perform: playerViewModel.removeAudio)
                    .onMove(perform: playerViewModel.moveAudio)
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
    @Published var currentAudioName: String = "未选择音频"
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentTimeString: String = "00:00"
    @Published var durationString: String = "00:00"

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

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
        panel.allowedContentTypes = [UTType.mp3, UTType.wav]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            for url in urls {
                if !audioFiles.contains(where: { $0.url == url }) {
                    var newAudio = AudioFile(url: url, name: url.lastPathComponent)
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        newAudio.duration = player.duration
                        newAudio.durationString = formatTime(player.duration)
                    }
                    audioFiles.append(newAudio)
                }
            }
            if currentIndex == nil && !audioFiles.isEmpty {
                playAtIndex(0)
            }
        }
        objectWillChange.send()
    }

    func playAtIndex(_ index: Int) {
        stop()
        currentIndex = index
        let audio = audioFiles[index]
        setupAudioPlayer(with: audio.url)
    }

    private func setupAudioPlayer(with url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            currentAudioName = url.lastPathComponent
            duration = audioPlayer?.duration ?? 0
            durationString = formatTime(duration)
            startTimer()
        } catch {
            print("Audio loading failed: \(error)")
            currentAudioName = "Audio loading failed"
        }
        objectWillChange.send()
    }

    func playPause() {
        guard let player = audioPlayer, let _ = currentIndex else { return }
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
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
            if isPlaying {
                audioPlayer?.play()
                startTimer()
            }
        }
        objectWillChange.send()
    }

    func playNext() {
        if let index = currentIndex, index < audioFiles.count - 1 {
            playAtIndex(index + 1)
            if isPlaying {
                audioPlayer?.play()
                startTimer()
            }
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
            currentAudioName = "未选择音频"
        } else if let current = currentIndex, current >= audioFiles.count {
            currentIndex = audioFiles.count - 1
        }
        objectWillChange.send()
    }

    func moveAudio(from source: IndexSet, to destination: Int) {
        audioFiles.move(fromOffsets: source, toOffset: destination)
        if let current = currentIndex {
            currentIndex = audioFiles.firstIndex(where: { $0.id == audioFiles[current].id })
        }
        objectWillChange.send()
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
