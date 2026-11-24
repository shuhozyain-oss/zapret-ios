import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class AudioPlayer: ObservableObject {
    @Published var state = PlayerState()
    
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var queue: [Track] = []
    private var currentIndex: Int = 0
    private var resolver: ((Track) async -> String?)?
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
        try? session.setActive(true)
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
    }
    
    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    func play(tracks: [Track], startIndex: Int = 0, urlResolver: @escaping (Track) async -> String?) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.queue = tracks
            self.currentIndex = max(0, startIndex)
            self.resolver = urlResolver
            self.playCurrent()
        }
    }
    
    private func playCurrent() {
        guard currentIndex >= 0, currentIndex < queue.count else {
            state.isPlaying = false
            return
        }
        let track = queue[currentIndex]
        let resolver = self.resolver
        
        Task { [weak self] in
            guard let self = self else { return }
            var urlString = track.streamUrl
            if (urlString?.isEmpty ?? true), track.requiresResolution, let resolver = resolver {
                urlString = await resolver(track)
            }
            guard let finalUrl = urlString, let url = URL(string: finalUrl) else {
                await MainActor.run { self.state.isPlaying = false }
                return
            }
            let item = AVPlayerItem(url: url)
            await MainActor.run {
                self.install(item: item, track: track)
            }
        }
    }
    
    private func install(item: AVPlayerItem, track: Track) {
        removeTimeObserver()
        removeEndObserver()
        
        state.currentTrack = track
        state.durationMs = Double(track.durationSec) * 1000
        state.positionMs = 0
        state.isPlaying = false
        
        player.replaceCurrentItem(with: item)
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.next()
        }
        
        let interval = CMTime(seconds: 0.4, preferredTimescale: 1000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.state.positionMs = time.seconds * 1000
            if let duration = self.player.currentItem?.duration, duration.isNumeric {
                self.state.durationMs = duration.seconds * 1000
            }
        }
        
        player.play()
        state.isPlaying = true
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func removeEndObserver() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
    }
    
    func togglePlayPause() {
        onMain { [weak self] in
            guard let self = self, self.player.currentItem != nil else { return }
            if self.state.isPlaying {
                self.player.pause()
                self.state.isPlaying = false
            } else {
                self.player.play()
                self.state.isPlaying = true
            }
        }
    }
    
    func seek(to ms: Double) {
        onMain { [weak self] in
            guard let self = self else { return }
            let time = CMTime(seconds: ms / 1000, preferredTimescale: 1000)
            self.player.seek(to: time)
            self.state.positionMs = ms
        }
    }
    
    func next() {
        onMain { [weak self] in
            guard let self = self, !self.queue.isEmpty else { return }
            self.currentIndex = (self.currentIndex + 1) % self.queue.count
            self.playCurrent()
        }
    }
    
    func previous() {
        onMain { [weak self] in
            guard let self = self, !self.queue.isEmpty else { return }
            self.currentIndex = max(0, self.currentIndex - 1)
            self.playCurrent()
        }
    }
    
    func release() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.player.pause()
            self.removeTimeObserver()
            self.removeEndObserver()
            self.player.replaceCurrentItem(with: nil)
        }
    }
}