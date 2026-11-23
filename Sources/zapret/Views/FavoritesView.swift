import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var vm: MusicViewModel
    
    var body: some View {
        NavigationView {
            if vm.favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Избранное пусто")
                        .font(.headline).bold()
                    Text("Нажми ♥ у трека, чтобы добавить")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(vm.favorites) { track in
                    TrackRowView(
                        track: track,
                        vm: vm,
                        onFavoriteToggle: { vm.toggleFavorite(track) },
                        onDownload: { vm.download(track) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.play(track, queue: vm.favorites)
                    }
                }
            }
            .navigationTitle("Избранное")
        }
        .navigationViewStyle(.stack)
    }
}