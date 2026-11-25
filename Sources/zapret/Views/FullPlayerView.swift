import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var vm: MusicViewModel
    @Binding var isPresented: Bool
    @State private var scrubbing: CGFloat?
    
    var body: some View {
        if let track = vm.playerState.currentTrack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1C1C1E"), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    Spacer()
                    
                    ArtworkView(url: track.artworkUrl, seed: track.title, size: 280)
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
                    
                    seekBar
                    
                    Spacer().frame(height: 22)
                    
                    controls(track: track)
                    
                    Spacer().frame(height: 18)
                    
                    modifiers
                    
                    Spacer()
                }
            }
        }
    }
    
    private var modifiers: some View {
        HStack(spacing: 0) {
            Button { vm.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(vm.playerState.shuffle ? .accentColor : .secondary)
                    .frame(width: 52, height: 44)
                    .background(vm.playerState.shuffle ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button { vm.cycleRepeat() } label: {
                Image(systemName: vm.playerState.repeatMode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(vm.playerState.repeatMode == .off ? .secondary : .accentColor)
                    .frame(width: 52, height: 44)
                    .background(vm.playerState.repeatMode == .off ? Color.clear : Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }
    
    private var header: some View {
        HStack {
            Button { isPresented = false } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            Text("СЕЙЧАС ИГРАЕТ")
                .font(.caption).bold()
                .foregroundColor(.secondary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var seekBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 4).cornerRadius(2)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                            scrubbing = p
                            vm.seek(to: p * vm.playerState.durationMs)
                        }
                        .onEnded { _ in
                            scrubbing = nil
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
    }
    
    private func controls(track: Track) -> some View {
        HStack(spacing: 20) {
            Button { vm.toggleFavorite(track) } label: {
                Image(systemName: vm.isFavorite(track) ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(vm.isFavorite(track) ? .red : .white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button { vm.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button { vm.togglePlayPause() } label: {
                Image(systemName: vm.playerState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.black)
                    .frame(width: 76, height: 76)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button { vm.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button { vm.download(track) } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var progress: CGFloat {
        let value = scrubbing ?? fraction
        return min(max(value, 0), 1)
    }
    
    private var fraction: CGFloat {
        guard vm.playerState.durationMs > 0 else { return 0 }
        return vm.playerState.positionMs / vm.playerState.durationMs
    }
    
    private func formatTime(_ ms: Double) -> String {
        let totalSec = Int(ms / 1000)
        return String(format: "%d:%02d", totalSec / 60, totalSec % 60)
    }
}