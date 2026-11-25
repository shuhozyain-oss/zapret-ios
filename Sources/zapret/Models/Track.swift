import Foundation

enum Source: String, CaseIterable, Identifiable, Codable {
    case youtube = "YouTube"
    case soundcloud = "SoundCloud"
    case deezer = "Deezer"
    case itunes = "Apple Music"
    case archive = "Archive.org"
    case local = "Устройство"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct Track: Identifiable, Equatable, Codable {
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
    var isNilOrEmptyStream: Bool { streamUrl?.isEmpty != false }
}

enum RepeatMode: String, CaseIterable, Codable {
    case off
    case all
    case one
    
    /// Порядок переключения по нажатию кнопки «повтор».
    func next() -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
    
    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

struct PlayerState: Equatable {
    var currentTrack: Track?
    var isPlaying: Bool = false
    var positionMs: Double = 0
    var durationMs: Double = 0
    var queue: [Track] = []
    var loading: Bool = false
    var loadingKey: String?
    var shuffle: Bool = false
    var repeatMode: RepeatMode = .off
}