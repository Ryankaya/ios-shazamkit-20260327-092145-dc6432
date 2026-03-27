import SwiftUI

// MARK: - TrackCardView

struct TrackCardView: View {

    enum Style {
        case compact   // used in history list rows
        case banner    // used in the recognition result overlay
    }

    let track: RecognizedTrack
    let style: Style

    var body: some View {
        switch style {
        case .compact: compactLayout
        case .banner:  bannerLayout
        }
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        HStack(spacing: 12) {
            artworkView(size: 56, cornerRatio: 0.18)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(track.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Banner Layout

    private var bannerLayout: some View {
        HStack(spacing: 16) {
            artworkView(size: 72, cornerRatio: 0.18)

            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                if !track.genreLabel.isEmpty {
                    Text(track.genreLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Artwork

    @ViewBuilder
    private func artworkView(size: CGFloat, cornerRatio: CGFloat) -> some View {
        let radius = size * cornerRatio
        if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    artworkPlaceholder(size: size)
                case .empty:
                    Color.purple.opacity(0.15)
                        .overlay(ProgressView().scaleEffect(0.7))
                @unknown default:
                    artworkPlaceholder(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            artworkPlaceholder(size: size)
                .frame(width: size, height: size)
        }
    }

    private func artworkPlaceholder(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.18)
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.4), Color.indigo.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        // Mocking data directly; SHMediaItem cannot be instantiated in previews.
        Text("TrackCardView Preview")
            .foregroundStyle(.secondary)
    }
    .padding()
}
