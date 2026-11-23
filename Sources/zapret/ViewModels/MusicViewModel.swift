import Foundation
import Combine

final class MusicViewModel: ObservableObject {
    enum Tab { case search, favorites, device }
    
    @Published var tab: Tab = .search
    @Published var searchQuery = ""
    @Published var searchResults: [Track] = []
    @Published var searchLoading = false
    @Published var deviceTracks: [Track] = []
    @Published var favorites: [Track] = []
    @Published var downloadStates: [String: DownloadManager.DownloadState] = [:]
    
    private let repository = MusicRepository()
    private let downloadManager = DownloadManager()
    private let favoritesStore = FavoritesStore()
    private let audioPlayer = AudioPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    var playerState: PlayerState { audioPlayer.state }
    
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
    }
    
    func performSearch(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            searchLoading = false
            return
        }
        
        searchLoading = true
        searchTask = Task {
            let providers: [MusicProvider] = [
                DeezerProvider(),
                ItunesProvider(),
                ArchiveOrgProvider(),
                YouTubeProvider()
            ]
            
            do {
                var results: [Track] = []
                for provider in providers {
                    let tracks = try await provider.search(query: query)
                    results.append(contentsOf: tracks)
                }
                await MainActor.run {
                    self.searchResults = results
                    self.searchLoading = false
                }
            } catch {
                await MainActor.run {
                    self.searchResults = []
                    self.searchLoading = false
                }
            }
        }
    }
    
    func selectTab(_ tab: Tab) {
        self.tab = tab
        if tab == .device && deviceTracks.isEmpty { refreshDevice() }
    }
    
    func refreshDevice() {
        // Simplified - real implementation would use MPMediaQuery
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
        downloadManager.startDownload(for: track) { [weak self] t in
            await self?.resolveStreamUrl(for: t)
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
            // YouTube needs yt-dlp or similar - use deep link
            return track.openUrl
        default:
            return track.streamUrl
        }
    }
    
    func play(_ track: Track, queue: [Track]) {
        guard let index = queue.firstIndex(where: { $0.id == track.id && $0.source == track.source }) else { return }
        
        // Check if downloaded
        if let localUrl = downloadManager.localUri(for: track.key) {
            var playable = track
            playable = Track(
                id: track.id, title: track.title, artist: track.artist, album: track.album,
                durationSec: track.durationSec, artworkUrl: track.artworkUrl,
                streamUrl: localUrl.absoluteString, source: track.source,
                openUrl: track.openUrl, requiresResolution: false, isPreview: track.isPreview
            )
            audioPlayer.play(tracks: [playable], startIndex: 0) { _ in
                Task { nil }
            }
        } else if track.requiresResolution || track.streamUrl?.isEmpty != false {
            // Need to resolve
            Task {
                let url = await resolveStreamUrl(for: track)
                var playable = track
                if let u = url {
                    playable = Track(
                        id: track.id, title: track.title, artist: track.artist, album: track.album,
                        durationSec: track.durationSec, artworkUrl: track.artworkUrl,
                        streamUrl: u, source: track.source,
                        openUrl: track.openUrl, requiresResolution: false, isPreview: track.isPreview
                    )
                }
                audioPlayer.play(tracks: [playable], startIndex: 0) { _ in
                    Task { nil }
                }
            }
        } else {
            audioPlayer.play(tracks: queue.filter { !$0.streamUrl.isNilOrEmpty }, startIndex: index) { _ in
                Task { nil }
            }
        }
    }
    
    func togglePlayPause() { audioPlayer.togglePlayPause() }
    func seek(to ms: Double) { audioPlayer.seek(to: ms) }
    func next() { audioPlayer.next() }
    func previous() { audioPlayer.previous() }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self == nil || self!.isEmpty }
}