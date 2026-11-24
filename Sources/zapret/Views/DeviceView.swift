import SwiftUI

struct DeviceView: View {
    @EnvironmentObject var vm: MusicViewModel
    
    var body: some View {
        NavigationView {
            Group {
                if vm.deviceTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Нет музыки")
                            .font(.headline).bold()
                        Text("На устройстве не найдено аудиофайлов")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(vm.deviceTracks) { track in
                        TrackRowView(
                            track: track,
                            vm: vm,
                            onFavoriteToggle: { vm.toggleFavorite(track) },
                            onDownload: { vm.download(track) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.play(track, queue: vm.deviceTracks)
                        }
                    }
                }
            }
            .navigationTitle("Устройство")
        }
        .navigationViewStyle(.stack)
    }
}