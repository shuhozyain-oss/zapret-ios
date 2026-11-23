import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var vm: MusicViewModel
    @Binding var showFullPlayer: Bool
    
    var body: some View {
        if let track = vm.playerState.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ArtworkView(url: track.artworkUrl, seed: track.title, size: 46)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title).font(.subheadline).bold().lineLimit(1)
                        Text(track.artist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: { vm.togglePlayPause() }) {
                        Image(systemName: vm.playerState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { vm.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "111111"))
                .cornerRadius(22)
                .shadow(radius: 8)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
                .onTapGesture { showFullPlayer = true }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.2))
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 2)
            }
        }
    }
    
    private var progress: CGFloat {
        guard vm.playerState.durationMs > 0 else { return 0 }
        return min(max(vm.playerState.positionMs / vm.playerState.durationMs, 0), 1)
    }
}