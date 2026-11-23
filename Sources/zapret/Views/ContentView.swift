import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: MusicViewModel
    @State private var showFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: Binding(
                get: { vm.tab },
                set: { vm.selectTab($0) }
            )) {
                SearchView()
                    .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
                    .tag(MusicViewModel.Tab.search)
                
                FavoritesView()
                    .tabItem { Label("Избранное", systemImage: "heart") }
                    .tag(MusicViewModel.Tab.favorites)
                
                DeviceView()
                    .tabItem { Label("Устройство", systemImage: "iphone") }
                    .tag(MusicViewModel.Tab.device)
            }
            .accentColor(.white)
            
            if vm.playerState.currentTrack != nil {
                MiniPlayerView(showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 49)
            }
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
    }
}