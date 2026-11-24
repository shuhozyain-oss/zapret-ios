import SwiftUI

struct SearchView: View {
    @EnvironmentObject var vm: MusicViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextField("Найти трек или исполнителя", text: $vm.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                if vm.searchLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if vm.searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Ничего не найдено")
                            .font(.headline).bold()
                        Text("YouTube · SoundCloud · Archive.org — полные треки")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(vm.searchResults) { track in
                        TrackRowView(
                            track: track,
                            vm: vm,
                            onFavoriteToggle: { vm.toggleFavorite(track) },
                            onDownload: { vm.download(track) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.play(track, queue: vm.searchResults)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("zapret")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}