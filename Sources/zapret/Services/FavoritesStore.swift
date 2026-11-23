import Foundation
import Combine

final class FavoritesStore: ObservableObject {
    @Published var favorites: [Track] = []
    
    private let storageKey = "ios_favorites"
    
    init() {
        load()
    }
    
    func toggle(_ track: Track) {
        if let idx = favorites.firstIndex(where: { $0.id == track.id && $0.source == track.source }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(track)
        }
        save()
    }
    
    func isFavorite(_ track: Track) -> Bool {
        favorites.contains { $0.id == track.id && $0.source == track.source }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Track].self, from: data) else { return }
        favorites = decoded
    }
}