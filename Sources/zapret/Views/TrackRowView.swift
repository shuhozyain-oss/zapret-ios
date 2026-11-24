import SwiftUI

struct TrackRowView: View {
    let track: Track
    @ObservedObject var vm: MusicViewModel
    let onFavoriteToggle: () -> Void
    let onDownload: () -> Void
    
    var isCurrent: Bool { vm.playerState.currentTrack?.id == track.id && vm.playerState.currentTrack?.source == track.source }
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: track.artworkUrl, seed: track.title, size: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(track.source.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if isCurrent {
                PlayingBarsView(color: .white)
                    .frame(width: 20, height: 16)
            }
            
            DownloadButtonView(state: vm.downloadStates[track.key] ?? .idle, onDownload: onDownload)
            
            Button(action: onFavoriteToggle) {
                Image(systemName: vm.isFavorite(track) ? "heart.fill" : "heart")
                    .foregroundColor(vm.isFavorite(track) ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
        .background(isCurrent ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct ArtworkView: View {
    let url: String?
    let seed: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            if let urlStr = url, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: size, height: size)
                .clipped()
                .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .cornerRadius(12)
                    .overlay(
                        Text(String(seed.prefix(1)).uppercased())
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

struct PlayingBarsView: View {
    let color: Color
    @State private var heights: [ CGFloat ] = [0.35, 1.0, 0.5]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: heights[i] * 16)
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                heights = [1.0, 0.4, 1.0]
            }
        }
    }
}

struct DownloadButtonView: View {
    let state: DownloadManager.DownloadState
    let onDownload: () -> Void
    
    var body: some View {
        Button(action: onDownload) {
            switch state {
            case .idle:
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.secondary)
            case .downloading(let progress):
                ZStack {
                    Circle().stroke(lineWidth: 2).opacity(0.3).foregroundColor(.secondary)
                    Circle().trim(from: 0, to: CGFloat(progress)).stroke(lineWidth: 2).foregroundColor(.secondary)
                }
                .frame(width: 20, height: 20)
            case .downloaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            }
        }
    }
}