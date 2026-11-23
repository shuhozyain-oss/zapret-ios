import Foundation
import Combine

final class MusicRepository: ObservableObject {
    @Published var tab: Tab = .search
    @Published var search: SearchState = .init()
    @Published var deviceTracks: [Track] = []
    @Published var favorites: [Track] = []
    @Published var downloadStates: [String: DownloadState] = [:]
    
    enum Tab { case search, favorites, device }
    struct SearchState: Equatable { var query: String = "", var results: [Track] = [], var loading: Bool = false }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadFavorites()
        loadDeviceTracks()
    }
    
    // MARK: - Favorites
    func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorites"),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) {
            self.favorites = decoded
        }
    }
    
    func toggleFavorite(_ track: Track) {
        if let idx = favorites.firstIndex(where: { $0.id == track.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(track)
        }
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "favorites")
        }
        loadFavorites()
    }
    
    func isFavorite(_ track: Track) -> Bool { favorites.contains(where: { $0.id == track.id }) }
    
    // MARK: - Device
    func loadDeviceTracks() {
        // Read from iTunes library via AssetsLibrary or MediaItems - simplified
        deviceTracks = [] // Placeholder - full Core Media integration needed
    }
    
    func refreshDevice() { loadDeviceTracks() }
    
    // MARK: - Search
    func search(query: String) {
        // Parallel search providers
        guard !query.isEmpty else { return }
        // Each provider returns [Track]
        let providers: [Track] = [
            ...deezerSearch(query),
            ...itunesSearch(query),
            ...archiveSearch(query),
            ...youtubeSearch(query)
        ]
        self.search = .init(query: query, results: providers, loading: false)
    }
    
    // Provider search methods (simplified - use URLSession)
    private func deezerSearch(_ query: String) -> [Track] {
        // Deezer public API search - 30-sec previews
        [] // Implementation below
    }
    
    private func itunesSearch(_ query: String) -> [Track] {
        // iTunes/Apple Music search - 30-sec previews
        []
    }
    
    private func archiveSearch(_ query: String) -> [Track] {
        // Archive.org full-length audio
        []
    }
    
    private func youtubeSearch(_ query: String) -> [Track] {
        // YouTube deep link (open in official app)
        []
    }
}

final class DownloadManager: ObservableObject {
    @Published var states: [String: DownloadState] = [:]
    
    enum DownloadState: Equatable { case idle, downloading(progress: Float), downloaded, failed }
    
    func startDownload(for track: Track) {
        // Download stream URL to Documents directory
        // Simplified: just mark as downloading
        states[track.key] = .downloading(progress: 0)
    }
    
    func cancelDownload(for key: String) {
        states[key] = .idle
    }
    
    func localUri(for key: String) -> URL? {
        // Return file:// URL if downloaded
        nil // Placeholder
    }
}

final class FavoritesStore: ObservableObject {
    @Published var favorites: [Track] = []
    
    init() {
        load()
    }
    
    func toggle(_ track: Track) {
        if let idx = favorites.firstIndex(where: { $0.id == track.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(track)
        }
        save()
    }
    
    func isFavorite(_ track: Track) -> Bool { favorites.contains(where: { $0.id == track.id }) }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "ios_favorites")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "ios_favorites"),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) {
            favorites = decoded
        }
    }
}