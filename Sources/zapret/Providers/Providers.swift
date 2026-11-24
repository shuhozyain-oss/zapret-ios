import Foundation

protocol MusicProvider {
    var source: Source { get }
    func search(query: String) async throws -> [Track]
    func resolveStreamUrl(for identifier: String) async throws -> String?
}

final class DeezerProvider: MusicProvider {
    let source = Source.deezer
    
    func search(query: String) async throws -> [Track] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://api.deezer.com/search?q=\(encoded)&limit=25") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DeezerResponse.self, from: data)
        return response.data.map { $0.toTrack() }
    }
    
    func resolveStreamUrl(for identifier: String) async throws -> String? { nil }
}

struct DeezerResponse: Decodable { let data: [DeezerTrack] }
struct DeezerTrack: Decodable {
    let id: Int
    let title: String
    let preview: String?
    let duration: Int
    let link: String?
    let artist: DeezerArtist?
    let album: DeezerAlbum?
}
struct DeezerArtist: Decodable { let name: String }
struct DeezerAlbum: Decodable { let title: String; let cover_big: String?; let cover_xl: String? }

extension DeezerTrack {
    func toTrack() -> Track {
        Track(
            id: String(id),
            title: title,
            artist: artist?.name ?? "",
            album: album?.title ?? "",
            durationSec: duration,
            artworkUrl: album?.cover_big ?? album?.cover_xl,
            streamUrl: preview,
            source: .deezer,
            openUrl: link,
            requiresResolution: false,
            isPreview: true
        )
    }
}

final class ItunesProvider: MusicProvider {
    let source = Source.itunes
    
    func search(query: String) async throws -> [Track] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=25") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ItunesResponse.self, from: data)
        return response.results.map { $0.toTrack() }
    }
    
    func resolveStreamUrl(for identifier: String) async throws -> String? { nil }
}

struct ItunesResponse: Decodable { let results: [ItunesTrack] }
struct ItunesTrack: Decodable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let trackTimeMillis: Int
    let artworkUrl100: String?
    let previewUrl: String?
    let trackViewUrl: String?
}

extension ItunesTrack {
    func toTrack() -> Track {
        Track(
            id: String(trackId),
            title: trackName,
            artist: artistName,
            album: collectionName ?? "",
            durationSec: trackTimeMillis / 1000,
            artworkUrl: artworkUrl100?.replacingOccurrences(of: "100x100", with: "600x600"),
            streamUrl: previewUrl,
            source: .itunes,
            openUrl: trackViewUrl,
            requiresResolution: false,
            isPreview: true
        )
    }
}

final class ArchiveOrgProvider: MusicProvider {
    let source = Source.archive
    
    func search(query: String) async throws -> [Track] {
        let encoded = "\"\(query)\" AND mediatype:(audio)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://archive.org/advancedsearch.php?q=\(encoded)&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=creator&rows=15&page=1&output=json") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ArchiveSearchResponse.self, from: data)
        return response.response?.docs.map { $0.toTrack() } ?? []
    }
    
    func resolveStreamUrl(for identifier: String) async throws -> String? {
        guard let url = URL(string: "https://archive.org/metadata/\(identifier)") else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let meta = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        let audio = meta.files.first { file in
            let fmt = file.format?.lowercased() ?? ""
            return fmt.contains("mp3") || fmt.contains("ogg") || fmt.contains("flac") || fmt.contains("vbr") || fmt.contains("64kbps")
        } ?? meta.files.first { $0.name.lowercased().hasSuffix(".mp3") || $0.name.lowercased().hasSuffix(".ogg") }
        
        guard let file = audio else { return nil }
        let encodedName = file.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.replacingOccurrences(of: "+", with: "%20") ?? file.name
        return "https://archive.org/download/\(identifier)/\(encodedName)"
    }
}

struct ArchiveSearchResponse: Decodable { let response: ArchiveResponse? }
struct ArchiveResponse: Decodable { let docs: [ArchiveDoc] }
struct ArchiveDoc: Decodable {
    let identifier: String
    let title: StringList?
    let creator: StringList?
}
struct ArchiveMetadata: Decodable {
    let files: [ArchiveFile]
    let metadata: ArchiveMeta?
}
struct ArchiveFile: Decodable { let name: String; let format: String?; let size: String? }
struct ArchiveMeta: Decodable { let title: StringList?; let creator: StringList? }

/// archive.org отдаёт некоторые поля как строку, а некоторые как массив строк.
struct StringList: Decodable {
    let values: [String]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            values = [single]
        } else if let list = try? container.decode([String].self) {
            values = list
        } else {
            values = []
        }
    }
}

extension ArchiveDoc {
    func toTrack() -> Track {
        let title = self.title?.values.first ?? ""
        let artist = creator?.values.first ?? ""
        return Track(
            id: identifier,
            title: title.isEmpty ? identifier : title,
            artist: artist,
            album: "archive.org",
            durationSec: 0,
            artworkUrl: "https://archive.org/services/img/\(identifier)",
            streamUrl: nil,
            source: .archive,
            openUrl: "https://archive.org/details/\(identifier)",
            requiresResolution: true,
            isPreview: false
        )
    }
}
