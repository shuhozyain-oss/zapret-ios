import Foundation
import AVFoundation
import Combine

final class AudioPlayer: ObservableObject {
    @Published var state = PlayerState()
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var queue: [Track] = []
    private var currentIndex: Int = 0
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
    }
    
    func play(tracks: [Track], startIndex: Int = 0, urlResolver: @escaping (Track) async -> String?) {
        self.queue = tracks
        self.currentIndex = startIndex
        playCurrent(urlResolver: urlResolver)
    }
    
    private func playCurrent(urlResolver: @escaping (Track) async -> String?) {
        guard currentIndex < queue.count else { return }
        let track = queue[currentIndex]
        
        Task {
            var urlString = track.streamUrl
            if (urlString == nil || urlString!.isEmpty) && track.requiresResolution {
                urlString = await urlResolver(track)
            }
            guard let finalUrl = urlString, let url = URL(string: finalUrl) else {
                await MainActor.run { self.state.isPlaying = false }
                return
            }
            
            await MainActor.run {
                self.state.currentTrack = track
                self.state.durationMs = Double(track.durationSec) * 1000
                self.state.positionMs = 0
            }
            
            let playerItem = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: playerItem)
            self.player = player
            
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
                self?.next()
            }
            
            player.play()
            await MainActor.run { self.state.isPlaying = true }
            setupTimeObserver()
        }
    }
    
    private func setupTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        let interval = CMTime(seconds: 0.4, preferredTimescale: 1000)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.state.positionMs = time.seconds * 1000
            if let duration = self.player?.currentItem?.duration, duration.isNumeric {
                self.state.durationMs = duration.seconds * 1000
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if state.isPlaying {
            player.pause()
            state.isPlaying = false
        } else {
            player.play()
            state.isPlaying = true
        }
    }
    
    func seek(to ms: Double) {
        let time = CMTime(seconds: ms / 1000, preferredTimescale: 1000)
        player?.seek(to: time)
        state.positionMs = ms
    }
    
    func next() {
        currentIndex += 1
        if currentIndex >= queue.count {
            currentIndex = 0
        }
        // Need a resolver - simplified: reuse existing playCurrent
        // In production, store the resolver
    }
    
    func previous() {
        currentIndex = max(0, currentIndex - 1)
    }
    
    func release() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
    }
}