import SwiftUI

@main
struct zapretApp: App {
    @StateObject private var viewModel = MusicViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}