import SwiftUI

@main
struct SonicSenseApp: App {
    @StateObject private var viewModel = ShazamViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
