import Foundation

/// SoundCloud: поиск и получение ссылки на поток через публичный api-v2.
/// client_id берётся со страницы soundcloud.com (как это делают неофициальные клиенты).
final class SoundCloudProvider: MusicProvider {
    let source = Source.soundcloud

    private static let apiBase = "https://api-v2.soundcloud.com"
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private var cachedClientId: String?
    private var clientIdTask: Task<String?, Never>?

    func search(query: String) async throws -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let clientId = await getClientId() else { return [] }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(Self.apiBase)/search?q=\(encoded)&client_id=\(clientId)&limit=20&offset=0&linked_partitioning=1") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        let result = try JSONDecoder().decode(SoundCloudSearchResponse.self, from: data)
        return result.collection.map { $0.toTrack() }
    }

    func resolveStreamUrl(for identifier: String) async throws -> String? {
        guard let clientId = await getClientId() else { return nil }
        guard let url = URL(string: "\(Self.apiBase)/tracks/\(identifier)?client_id=\(clientId)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let track = try JSONDecoder().decode(SoundCloudTrack.self, from: data)
        let transcodings = track.media?.transcodings ?? []
        let progressive = transcodings.first { $0.format?.protocolValue == "progressive" }
        let hls = transcodings.first { $0.format?.protocolValue == "hls" }
        guard let chosen = progressive ?? hls else { return nil }

        return try await fetchStreamUrl(transcodingUrl: chosen.url, clientId: clientId)
    }

    private func fetchStreamUrl(transcodingUrl: String, clientId: String) async throws -> String? {
        let separator = transcodingUrl.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(transcodingUrl)\(separator)client_id=\(clientId)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let result = try JSONDecoder().decode(SoundCloudStreamResponse.self, from: data)
        return result.url
    }

    private func getClientId() async -> String? {
        if let cached = cachedClientId { return cached }
        if let task = clientIdTask { return await task.value }

        let task = Task<String?, Never> { [weak self] in
            let value = await Self.fetchClientId()
            self?.cachedClientId = value
            return value
        }
        clientIdTask = task
        return await task.value
    }

    private static func fetchClientId() async -> String? {
        guard let url = URL(string: "https://soundcloud.com") else { return nil }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else { return nil }

        if let range = html.range(of: "\"client_id\":\"") {
            let start = range.upperBound
            if let end = html[start...].firstIndex(of: "\"") {
                let value = String(html[start..<end])
                if value.count > 10 { return value }
            }
        }

        if let range = html.range(of: "client_id=") {
            let tail = html[range.upperBound...].prefix(64)
            let value = String(tail.prefix { $0.isLetter || $0.isNumber })
            if value.count > 10 { return value }
        }

        return nil
    }
}

struct SoundCloudSearchResponse: Decodable {
    let collection: [SoundCloudTrack]
}

struct SoundCloudTrack: Decodable {
    let id: Int
    let title: String
    let duration: Int?
    let artworkUrl: String?
    let permalinkUrl: String?
    let user: SoundCloudUser?
    let media: SoundCloudMedia?

    enum CodingKeys: String, CodingKey {
        case id, title, duration, user, media
        case artworkUrl = "artwork_url"
        case permalinkUrl = "permalink_url"
    }

    func toTrack() -> Track {
        Track(
            id: String(id),
            title: title.isEmpty ? "Без названия" : title,
            artist: user?.username ?? "",
            album: "SoundCloud",
            durationSec: duration ?? 0,
            artworkUrl: artworkUrl,
            streamUrl: nil,
            source: .soundcloud,
            openUrl: permalinkUrl ?? "https://soundcloud.com",
            requiresResolution: true,
            isPreview: false
        )
    }
}

struct SoundCloudUser: Decodable {
    let username: String?
}

struct SoundCloudMedia: Decodable {
    let transcodings: [SoundCloudTranscoding]?
}

struct SoundCloudTranscoding: Decodable {
    let url: String
    let preset: String?
    let format: SoundCloudFormat?
}

struct SoundCloudFormat: Decodable {
    let protocolValue: String?
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case protocolValue = "protocol"
        case mimeType = "mime_type"
    }
}

struct SoundCloudStreamResponse: Decodable {
    let url: String
}