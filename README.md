# SonicSense — ShazamKit Music Recognition

A production-level SwiftUI iOS app demonstrating **ShazamKit** — Apple's audio fingerprinting framework that identifies music from ambient sound using on-device and cloud-based matching.

## Feature: ShazamKit

ShazamKit (iOS 15+) lets you build audio recognition into your apps by matching audio against Apple's vast music catalog (or a custom catalog). It works by:

1. Capturing raw audio via `AVAudioEngine`
2. Generating a compact audio "signature" with `SHSignatureGenerator`
3. Matching the signature against the Shazam database via `SHSession`
4. Receiving rich metadata (`SHMediaItem`) including artwork, artist, genre, Apple Music URL

## Architecture (MVVM)

```
SonicSense/
├── App/
│   └── SonicSenseApp.swift          # @main entry, injects ShazamViewModel
├── Models/
│   └── RecognizedTrack.swift         # Value type wrapping SHMediaItem + Codable
├── ViewModels/
│   └── ShazamViewModel.swift         # ObservableObject; owns SHSession & AVAudioEngine
└── Views/
    ├── ContentView.swift             # TabView root
    ├── RecognitionView.swift         # Animated listen UI + PulsingRingsView
    ├── HistoryView.swift             # Recognized songs list
    ├── TrackCardView.swift           # Reusable card (compact + banner styles)
    └── TrackDetailView.swift         # Full detail sheet, Share + Apple Music links
```

### Layer responsibilities

| Layer | Type | Role |
|---|---|---|
| `RecognizedTrack` | `struct` (Codable, Equatable) | Pure data; wraps `SHMediaItem` snapshot |
| `RecognitionState` | `enum` (Equatable) | Finite state machine for the recognition flow |
| `ShazamViewModel` | `ObservableObject` | All business logic; zero SwiftUI imports |
| Views | `View` structs | Pure rendering; no business logic |

## Key Implementation Details

- **Audio capture**: `AVAudioEngine.inputNode` tap at 8192 buffer size
- **Signature generation**: `SHSignatureGenerator.append(_:at:)` accumulates 10 seconds of audio
- **Matching**: `SHSession.match(signature:)` → `SHSessionDelegate` callbacks
- **RMS level**: Used to animate the pulsing rings in response to audio volume
- **Persistence**: `Codable` history stored in `UserDefaults` (up to 100 tracks)
- **Threading**: Audio tap runs on real-time thread; UI updates dispatched via `DispatchQueue.main`

## Requirements

- iOS 16.2+
- Microphone permission (`NSMicrophoneUsageDescription` in Info.plist)
- No special entitlement needed for Apple catalog matching

## Apple Documentation

- [ShazamKit Overview](https://developer.apple.com/documentation/shazamkit)
- [SHSession — Matching Audio Signatures](https://developer.apple.com/documentation/shazamkit/shsession)
- [SHSignatureGenerator](https://developer.apple.com/documentation/shazamkit/shsignaturegenerator)
- [SHMediaItem](https://developer.apple.com/documentation/shazamkit/shmediaitem)
- [WWDC21: Explore ShazamKit](https://developer.apple.com/videos/play/wwdc2021/10051/)

## Creative Possibilities

ShazamKit unlocks experiences far beyond simple music ID:

- **Sonic tour guide**: Anchor AR overlays or contextual info to specific audio environments
- **Live concert companion**: Identify tracks in real time and display synchronized lyrics/setlist
- **Music memory journal**: Geo-tag recognized songs to create a map of your musical life
- **Custom catalog matching**: Train your own audio fingerprints for branded sound logos, ads, or accessibility cues in museums and venues
- **watchOS haptic sync**: Mirror song recognition to Apple Watch with haptic beat patterns via CoreHaptics
- **tvOS discovery mode**: Always-on TV app that silently identifies background music and surfaces links on screen
