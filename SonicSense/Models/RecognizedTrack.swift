import Foundation
import ShazamKit

// MARK: - Recognition State

enum RecognitionState: Equatable {
    case idle
    case listening
    case processing
    case matched
    case noMatch
    case error(String)

    var statusMessage: String {
        switch self {
        case .idle:           return "Tap to Recognize"
        case .listening:      return "Listening…"
        case .processing:     return "Identifying…"
        case .matched:        return "Match Found!"
        case .noMatch:        return "No Match Found"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .listening, .processing: return true
        default: return false
        }
    }
}

// MARK: - Recognized Track

struct RecognizedTrack: Identifiable, Codable, Equatable {
    let id: UUID
    let shazamID: String
    let title: String
    let artist: String
    let subtitle: String?
    let genres: [String]
    let artworkURL: URL?
    let appleMusicURL: URL?
    let webURL: URL?
    let isrc: String?
    let recognizedAt: Date

    init(from item: SHMediaItem) {
        self.id = UUID()
        self.shazamID = item.shazamID ?? ""
        self.title = item.title ?? "Unknown Title"
        self.artist = item.artist ?? "Unknown Artist"
        self.subtitle = item.subtitle
        self.genres = item.genres
        self.artworkURL = item.artworkURL
        self.appleMusicURL = item.appleMusicURL
        self.webURL = item.webURL
        self.isrc = item.isrc
        self.recognizedAt = Date()
    }

    var genreLabel: String {
        genres.prefix(2).joined(separator: " · ")
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: recognizedAt)
    }

    var shareText: String {
        "🎵 \(title) by \(artist) – recognized with SonicSense"
    }
}

// MARK: - Errors

enum RecognitionError: LocalizedError {
    case microphoneAccessDenied
    case audioEngineFailure(String)

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required. Enable it in Settings > SonicSense."
        case .audioEngineFailure(let reason):
            return "Audio engine failed: \(reason)"
        }
    }
}
