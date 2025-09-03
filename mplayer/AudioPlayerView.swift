//
//  AudioPlayerView.swift
//  mplayer
//
//  Created by Emin (Qiming Chu) on 2025/9/3.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioPlayerView: View {
    @StateObject private var playerViewModel = AudioPlayerViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("MPlayer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 音频文件信息
            Text(playerViewModel.audioName)
                .font(.title2)
                .foregroundColor(.gray)
            
            // 时间显示
            HStack {
                Text(playerViewModel.currentTimeString)
                Slider(value: $playerViewModel.currentTime, in: 0...playerViewModel.duration, onEditingChanged: { editing in
                    if !editing {
                        playerViewModel.seek(to: playerViewModel.currentTime)
                    }
                })
                Text(playerViewModel.durationString)
            }
            .padding(.horizontal)
            
            // 控制按钮
            HStack(spacing: 20) {
                Button(action: {
                    playerViewModel.selectAudioFile()
                }) {
                    Text("选择音频")
                        .frame(width: 100)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    playerViewModel.playPause()
                }) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                }.buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    playerViewModel.stop()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                }.buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

class AudioPlayerViewModel: ObservableObject {
    @Published var audioName: String = "未选择音频"
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentTimeString: String = "00:00"
    @Published var durationString: String = "00:00"
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func selectAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.mp3, UTType.wav]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            setupAudioPlayer(with: url)
        }
    }
    
    private func setupAudioPlayer(with url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioName = url.lastPathComponent
            duration = audioPlayer?.duration ?? 0
            durationString = formatTime(duration)
            startTimer()
        } catch {
            print("音频加载失败: \(error)")
            audioName = "音频加载失败"
        }
    }
    
    func playPause() {
        guard let player = audioPlayer else { return }
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        currentTimeString = "00:00"
        stopTimer()
        isPlaying = false
    }
    
    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
        currentTimeString = formatTime(time)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.currentTimeString = self.formatTime(player.currentTime)
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
}

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        AudioPlayerView()
    }
}
