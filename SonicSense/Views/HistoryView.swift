import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: ShazamViewModel
    @State private var showClearConfirmation = false
    @State private var selectedTrack: RecognizedTrack?

    var body: some View {
        NavigationView {
            Group {
                if viewModel.history.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !viewModel.history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") { showClearConfirmation = true }
                            .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                "Clear all recognition history?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    withAnimation { viewModel.clearHistory() }
                }
            }
            .sheet(item: $selectedTrack) { track in
                TrackDetailView(track: track)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.purple.opacity(0.4))

            Text("No Songs Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Songs you recognize will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            Section {
                ForEach(viewModel.history) { track in
                    Button {
                        selectedTrack = track
                    } label: {
                        TrackCardView(track: track, style: .compact)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    withAnimation {
                        indexSet.forEach { idx in
                            viewModel.deleteHistoryItem(viewModel.history[idx])
                        }
                    }
                }
            } header: {
                Text("\(viewModel.history.count) Song\(viewModel.history.count == 1 ? "" : "s")")
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    HistoryView()
        .environmentObject(ShazamViewModel())
}
