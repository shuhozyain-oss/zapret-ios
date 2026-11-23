import SwiftUI

struct SearchView: View {
    @EnvironmentObject var vm: MusicViewModel
    @State private var query = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextField("Найти трек или исполнителя", text: $vm.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                if vm.searchLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if query.isEmpty && vm.searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Найди и послушай")
                            .font(.headline).bold()
                        Text("YouTube · Archive.org — полные треки")
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
                }
            }
            .navigationTitle("zapret")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}