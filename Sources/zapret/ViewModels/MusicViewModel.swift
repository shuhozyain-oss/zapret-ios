import Foundation
import UIKit
import Combine

final class MusicViewModel: ObservableObject {
    enum Tab: Hashable { case search, favorites, device }
    
    @Published var tab: Tab = .search
    @Published var searchQuery = ""
    @Published var searchResults: [Track] = []
    @Published var searchLoading = false
    @Published var deviceTracks: [Track] = []
    @Published var favorites: [Track] = []
    @Published var downloadStates: [String: DownloadManager.DownloadState] = [:]
    @Published var playerState = PlayerState()
    
    private let downloadManager = DownloadManager()
    private let favoritesStore = FavoritesStore()
    private let audioPlayer = AudioPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    init() {
        bind()
        refreshDevice()
    }
    
    private func bind() {
        $searchQuery
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
        
        downloadManager.$states
            .assign(to: &$downloadStates)
        
        favoritesStore.$favorites
            .assign(to: &$favorites)
        
        audioPlayer.$state
            .assign(to: &$playerState)
    }
    
    func performSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchLoading = false
            return
        }
        
        searchLoading = true
        searchTask = Task { [weak self] in
            // Deezer и iTunes отдают только 30-секундные превью — в поиске не участвуют.
            let providers: [MusicProvider] = [
                ArchiveOrgProvider(),
                YouTubeProvider()
            ]
            
            var results: [Track] = []
            for provider in providers {
                if Task.isCancelled { return }
                if let tracks = try? await provider.search(query: trimmed) {
                    results.append(contentsOf: tracks)
                }
            }
            
            let fullTracks = results.filter { !$0.isPreview }
            
            await MainActor.run {
                guard let self = self else { return }
                self.searchResults = fullTracks
                self.searchLoading = false
            }
        }
    }
    
    func selectTab(_ tab: Tab) {
        self.tab = tab
        if tab == .device && deviceTracks.isEmpty { refreshDevice() }
    }
    
    func refreshDevice() {
        // Заглушка: на iOS нет прямого доступа к медиатеке без MPMediaLibrary
        deviceTracks = []
    }
    
    func toggleFavorite(_ track: Track) {
        favoritesStore.toggle(track)
    }
    
    func isFavorite(_ track: Track) -> Bool {
        favoritesStore.isFavorite(track)
    }
    
    func download(_ track: Track) {
        let key = track.key
        if downloadManager.isDownloaded(key) { return }
        downloadManager.startDownload(for: track) { [weak self] track in
            await self?.resolveStreamUrl(for: track)
        }
    }
    
    func cancelDownload(_ track: Track) {
        downloadManager.cancelDownload(for: track.key)
    }
    
    private func resolveStreamUrl(for track: Track) async -> String? {
        switch track.source {
        case .archive:
            return try? await ArchiveOrgProvider().resolveStreamUrl(for: track.id)
        case .youtube:
            return track.openUrl
        default:
            return track.streamUrl
        }
    }
    
    func play(_ track: Track, queue: [Track]) {
        if track.source == .youtube {
            if let openUrl = track.openUrl, let url = URL(string: openUrl) {
                UIApplication.shared.open(url)
            }
            return
        }
        
        if let localUrl = downloadManager.localUri(for: track.key) {
            let playable = replace(track, streamUrl: localUrl.absoluteString)
            audioPlayer.play(tracks: [playable]) { _ in nil }
            return
        }
        
        if track.requiresResolution || track.isNilOrEmptyStream {
            Task { [weak self] in
                guard let self = self else { return }
                let resolved = await self.resolveStreamUrl(for: track)
                let playable = resolved.isEmptyOrNil ? track : self.replace(track, streamUrl: resolved)
                self.audioPlayer.play(tracks: [playable]) { _ in nil }
            }
            return
        }
        
        let playable = queue.filter { !$0.isNilOrEmptyStream }
        guard let index = playable.firstIndex(where: { $0.id == track.id && $0.source == track.source }) else { return }
        audioPlayer.play(tracks: playable, startIndex: index) { _ in nil }
    }
    
    private func replace(_ track: Track, streamUrl: String?) -> Track {
        Track(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            durationSec: track.durationSec,
            artworkUrl: track.artworkUrl,
            streamUrl: streamUrl,
            source: track.source,
            openUrl: track.openUrl,
            requiresResolution: false,
            isPreview: track.isPreview
        )
    }
    
    func togglePlayPause() { audioPlayer.togglePlayPause() }
    func seek(to ms: Double) { audioPlayer.seek(to: ms) }
    func next() { audioPlayer.next() }
    func previous() { audioPlayer.previous() }
}

private extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool { self == nil || self!.isEmpty }
}