import SwiftUI

struct TrackDetailView: View {
    let track: RecognizedTrack
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    detailContent
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [track.shareText])
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            artworkOrGradient
                .frame(height: 340)
                .clipped()

            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 160)
        }
    }

    @ViewBuilder
    private var artworkOrGradient: some View {
        if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    gradientFallback
                }
            }
        } else {
            gradientFallback
        }
    }

    private var gradientFallback: some View {
        LinearGradient(
            colors: [.purple, .indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "music.note")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
        )
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleSection
            genrePills
            metaRow
            Divider()
            actionButtons
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(track.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            Text(track.artist)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let subtitle = track.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var genrePills: some View {
        if !track.genres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(track.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 20) {
            Label(track.formattedDate, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let isrc = track.isrc {
                Label(isrc, systemImage: "barcode")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let url = track.appleMusicURL {
                Link(destination: url) {
                    Label("Open in Apple Music", systemImage: "music.note")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .font(.headline)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.15, blue: 0.45), Color(red: 0.8, green: 0.1, blue: 0.3)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                }
            }

            if let url = track.webURL {
                Link(destination: url) {
                    Label("View on Shazam", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .font(.headline)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.primary)
                }
            }

            Button {
                showShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.headline)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
