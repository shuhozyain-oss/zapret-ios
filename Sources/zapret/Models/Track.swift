import Foundation

enum Source: String, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case deezer = "Deezer"
    case itunes = "Apple Music"
    case archive = "Archive.org"
    case local = "Устройство"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct Track: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let durationSec: Int
    let artworkUrl: String?
    let streamUrl: String?
    let source: Source
    let openUrl: String?
    let requiresResolution: Bool
    let isPreview: Bool
    
    var key: String { "\(source.rawValue):\(id)" }
}

struct PlayerState: Equatable {
    var currentTrack: Track?
    var isPlaying: Bool = false
    var positionMs: Double = 0
    var durationMs: Double = 0
    var queue: [Track] = []
    var loading: Bool = false
    var loadingKey: String?
}