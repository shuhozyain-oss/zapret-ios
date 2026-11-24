import Foundation

/// YouTube: поиск и получение прямой ссылки на аудио через публичные Piped/Invidious
/// инстансы (yt-dlp на iOS недоступен, поэтому работаем через открытые API-прокси).
final class YouTubeProvider: MusicProvider {
    let source = Source.youtube

    private static let pipedInstances = [
        "https://pipedapi.kavin.rocks",
        "https://pipedapi.adminforge.de",
        "https://pipedapi.private.coffee",
        "https://pipedapi.drgns.space",
        "https://pipedapi.leptons.xyz",
        "https://pipedapi.r4fo.com",
        "https://pipedapi.ducks.party",
        "https://api.piped.yt"
    ]

    private static let invidiousInstances = [
        "https://inv.nadeko.net",
        "https://invidious.nerdvpn.de",
        "https://yewtu.be",
        "https://invidious.jing.rocks",
        "https://iv.melmac.space",
        "https://invidious.privacyredirect.com"
    ]

    private var pipedBase: String?
    private var invidiousBase: String?

    func search(query: String) async throws -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let base = pipedBase,
           let tracks = await Self.pipedSearch(base: base, query: trimmed), !tracks.isEmpty {
            return tracks
        }
        if let (base, tracks) = await firstSuccess(Self.pipedInstances, { await Self.pipedSearch(base: $0, query: trimmed) }) {
            pipedBase = base
            if !tracks.isEmpty { return tracks }
        }

        if let base = invidiousBase,
           let tracks = await Self.invidiousSearch(base: base, query: trimmed), !tracks.isEmpty {
            return tracks
        }
        if let (base, tracks) = await firstSuccess(Self.invidiousInstances, { await Self.invidiousSearch(base: $0, query: trimmed) }) {
            invidiousBase = base
            if !tracks.isEmpty { return tracks }
        }

        return []
    }

    func resolveStreamUrl(for identifier: String) async throws -> String? {
        if let base = pipedBase, let url = await Self.pipedStream(base: base, videoId: identifier) {
            return url
        }
        if let (base, url) = await firstSuccess(Self.pipedInstances, { await Self.pipedStream(base: $0, videoId: identifier) }) {
            pipedBase = base
            return url
        }

        if let base = invidiousBase, let url = await Self.invidiousStream(base: base, videoId: identifier) {
            return url
        }
        if let (base, url) = await firstSuccess(Self.invidiousInstances, { await Self.invidiousStream(base: $0, videoId: identifier) }) {
            invidiousBase = base
            return url
        }

        return nil
    }

    private func firstSuccess<T: Sendable>(_ bases: [String], _ operation: @escaping (String) async -> T?) async -> (String, T)? {
        guard !bases.isEmpty else { return nil }
        return await withTaskGroup(of: (String, T?).self) { group in
            for base in bases {
                group.addTask { (base, await operation(base)) }
            }
            for await (base, result) in group {
                if let result = result {
                    group.cancelAll()
                    return (base, result)
                }
            }
            return nil
        }
    }

    // MARK: - Piped

    private static func pipedSearch(base: String, query: String) async -> [Track]? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(base)/search?q=\(encoded)&filter=music_songs") else { return nil }
        guard let data = await fetch(url: url) else { return nil }
        guard let result = try? JSONDecoder().decode(PipedSearchResponse.self, from: data) else { return nil }

        let tracks = (result.items ?? []).compactMap { $0.toTrack() }
        return tracks.isEmpty ? nil : tracks
    }

    private static func pipedStream(base: String, videoId: String) async -> String? {
        guard !videoId.isEmpty,
              let url = URL(string: "\(base)/streams/\(videoId)") else { return nil }
        guard let data = await fetch(url: url) else { return nil }
        guard let result = try? JSONDecoder().decode(PipedStreamsResponse.self, from: data) else { return nil }

        let audio = result.audioStreams ?? []
        if let mp4 = audio.first(where: { $0.mimeType?.hasPrefix("audio/mp4") == true }) { return mp4.url }
        if let anyMp4 = audio.first(where: { ($0.mimeType ?? "").contains("mp4") }) { return anyMp4.url }

        let video = result.videoStreams ?? []
        if let muxed = video.first(where: { $0.videoOnly == false && $0.mimeType?.hasPrefix("video/mp4") == true }) {
            return muxed.url
        }
        return nil
    }

    // MARK: - Invidious

    private static func invidiousSearch(base: String, query: String) async -> [Track]? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(base)/api/v1/search?q=\(encoded)") else { return nil }
        guard let data = await fetch(url: url) else { return nil }
        guard let items = try? JSONDecoder().decode([InvidiousItem].self, from: data) else { return nil }

        let tracks = items.compactMap { $0.toTrack() }
        return tracks.isEmpty ? nil : tracks
    }

    private static func invidiousStream(base: String, videoId: String) async -> String? {
        guard !videoId.isEmpty,
              let url = URL(string: "\(base)/api/v1/videos/\(videoId)") else { return nil }
        guard let data = await fetch(url: url) else { return nil }
        guard let video = try? JSONDecoder().decode(InvidiousVideo.self, from: data) else { return nil }

        let formats = video.adaptiveFormats ?? []
        if let mp4 = formats.first(where: { $0.type?.hasPrefix("audio/mp4") == true }) { return mp4.url }
        if let anyMp4 = formats.first(where: {
            guard let type = $0.type else { return false }
            return type.contains("mp4") && !type.hasPrefix("video/mp4")
        }) {
            return anyMp4.url
        }
        return nil
    }

    private static func fetch(url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return data
    }
}

struct PipedSearchResponse: Decodable {
    let items: [PipedItem]?
}

struct PipedItem: Decodable {
    let url: String?
    let title: String?
    let uploaderName: String?
    let duration: Int?
    let thumbnail: String?

    func toTrack() -> Track? {
        guard let url = url, let videoId = Self.videoId(from: url), !videoId.isEmpty else { return nil }
        return Track(
            id: videoId,
            title: title ?? "Без названия",
            artist: uploaderName ?? "",
            album: "YouTube",
            durationSec: duration ?? 0,
            artworkUrl: thumbnail,
            streamUrl: nil,
            source: .youtube,
            openUrl: "https://www.youtube.com/watch?v=\(videoId)",
            requiresResolution: true,
            isPreview: false
        )
    }

    static func videoId(from url: String) -> String? {
        guard let range = url.range(of: "v=") else { return nil }
        let tail = url[range.upperBound...]
        let value = tail.prefix { $0 != "&" }
        return value.isEmpty ? nil : String(value)
    }
}

struct PipedStreamsResponse: Decodable {
    let audioStreams: [PipedStream]?
    let videoStreams: [PipedStream]?
}

struct PipedStream: Decodable {
    let url: String
    let mimeType: String?
    let videoOnly: Bool?
    let quality: String?
}

struct InvidiousItem: Decodable {
    let videoId: String?
    let title: String?
    let author: String?
    let lengthSeconds: Int?
    let videoThumbnails: [InvidiousThumbnail]?

    func toTrack() -> Track? {
        guard let videoId = videoId, !videoId.isEmpty else { return nil }
        let artwork = videoThumbnails?.last?.url ?? videoThumbnails?.first?.url
        return Track(
            id: videoId,
            title: title ?? "Без названия",
            artist: author ?? "",
            album: "YouTube",
            durationSec: lengthSeconds ?? 0,
            artworkUrl: artwork,
            streamUrl: nil,
            source: .youtube,
            openUrl: "https://www.youtube.com/watch?v=\(videoId)",
            requiresResolution: true,
            isPreview: false
        )
    }
}

struct InvidiousThumbnail: Decodable {
    let url: String?
}

struct InvidiousVideo: Decodable {
    let adaptiveFormats: [InvidiousFormat]?
}

struct InvidiousFormat: Decodable {
    let url: String
    let type: String?
}