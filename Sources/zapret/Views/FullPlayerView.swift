import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var vm: MusicViewModel
    @Environment(\.dismiss) var dismiss
    @State private var progress: CGFloat = 0
    
    var body: some View {
        guard let track = vm.playerState.currentTrack else { return AnyView(EmptyView()) }
        
        return AnyView(
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let artworkUrl = track.artworkUrl, let url = URL(string: artworkUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray
                    }
                    .blur(radius: 70)
                    .ignoresSafeArea()
                }
                
                Color.black.opacity(0.6).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text("NOW PLAYING")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    ArtworkView(url: track.artworkUrl, seed: track.title, size: 300)
                        .shadow(radius: 20)
                        .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 36)
                    
                    Text(track.title)
                        .font(.title).bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Text(track.artist)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 30)
                    
                    // Seek bar
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 4).cornerRadius(2)
                                Rectangle().fill(Color.white).frame(width: geo.size.width * progress, height: 4).cornerRadius(2)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let p = min(max(value.location.x / geo.size.width, 0), 1)
                                        progress = p
                                        vm.seek(to: p * vm.playerState.durationMs)
                                    }
                            )
                        }
                        .frame(height: 4)
                        
                        HStack {
                            Text(formatTime(vm.playerState.positionMs))
                            Spacer()
                            Text(formatTime(vm.playerState.durationMs))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer().frame(height: 22)
                    
                    HStack(spacing: 20) {
                        Button { vm.toggleFavorite(track) } label: {
                            Image(systemName: vm.isFavorite(track) ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(vm.isFavorite(track) ? .red : .white)
                                .frame(width: 52, height: 52)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button { vm.previous() } label: {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button { vm.togglePlayPause() } label: {
                            Image(systemName: vm.playerState.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 38))
                                .foregroundColor(.black)
                                .frame(width: 76, height: 76)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        
                        Button { vm.next() } label: {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button { vm.download(track) } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer()
                }
            }
        )
    }
    
    private func formatTime(_ ms: Double) -> String {
        let totalSec = Int(ms / 1000)
        return String(format: "%d:%02d", totalSec / 60, totalSec % 60)
    }
}