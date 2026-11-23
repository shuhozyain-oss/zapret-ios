import Foundation
import AVFoundation

final class DownloadManager: ObservableObject {
    @Published var states: [String: DownloadState] = [:]
    
    enum DownloadState: Equatable {
        case idle
        case downloading(progress: Float)
        case downloaded
        case failed
    }
    
    private let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    func startDownload(for track: Track, urlResolver: @escaping (Track) async -> String?) {
        let key = track.key
        if states[key] == .downloaded { return }
        states[key] = .downloading(progress: 0)
        
        Task {
            let finalUrl = await urlResolver(track)
            guard let urlStr = finalUrl, let url = URL(string: urlStr) else {
                await MainActor.run { states[key] = .failed }
                return
            }
            
            let (data, _) = try? await URLSession.shared.data(from: url)
            guard let data = data else {
                await MainActor.run { states[key] = .failed }
                return
            }
            
            let fileURL = documents.appendingPathComponent("\(key.hash).mp3")
            try? data.write(to: fileURL)
            await MainActor.run { states[key] = .downloaded }
        }
    }
    
    func cancelDownload(for key: String) {
        states[key] = .idle
        let fileURL = documents.appendingPathComponent("\(key.hash).mp3")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func localUri(for key: String) -> URL? {
        let fileURL = documents.appendingPathComponent("\(key.hash).mp3")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func isDownloaded(_ key: String) -> Bool {
        let fileURL = documents.appendingPathComponent("\(key.hash).mp3")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}