import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ShazamViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RecognitionView()
                .tabItem {
                    Label("Recognize", systemImage: "waveform.circle.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)
        }
        .tint(.purple)
    }
}

#Preview {
    ContentView()
        .environmentObject(ShazamViewModel())
}
