import Foundation
import ShazamKit
import AVFoundation

// MARK: - ShazamViewModel

final class ShazamViewModel: NSObject, ObservableObject {

    // MARK: - Published

    @Published private(set) var recognitionState: RecognitionState = .idle
    @Published private(set) var currentTrack: RecognizedTrack?
    @Published private(set) var history: [RecognizedTrack] = []
    @Published private(set) var audioLevel: Float = 0

    // MARK: - Private

    private var session: SHSession?
    private let audioEngine = AVAudioEngine()
    private var timeoutTimer: Timer?
    private var animTimer: Timer?
    private var animPhase: Double = 0
    private var didFindMatch = false

    private let historyKey = "com.ryankaya.sonicsense.history"
    private let maxHistoryItems = 100

    // MARK: - Init

    override init() {
        super.init()
        loadHistory()
    }

    deinit { stopEverything() }

    // MARK: - Public

    func toggleListening() {
        switch recognitionState {
        case .idle, .noMatch, .error:
            startRecognition()
        case .listening:
            stopEverything()
            recognitionState = .idle
        default:
            break
        }
    }

    func resetState() {
        stopEverything()
        currentTrack = nil
        recognitionState = .idle
    }

    func deleteHistoryItem(_ track: RecognizedTrack) {
        history.removeAll { $0.id == track.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    // MARK: - Recognition

    private func startRecognition() {
        requestMicPermission { [weak self] granted in
            guard let self else { return }
            if granted {
                self.recognitionState = .listening
                self.didFindMatch = false
                self.startFakeAudioAnimation()
                self.startStreamingMatch()
            } else {
                self.recognitionState = .error("Microphone access denied. Enable in Settings > Privacy > Microphone.")
            }
        }
    }

    private func requestMicPermission(completion: @escaping (Bool) -> Void) {
        let perm = AVAudioSession.sharedInstance().recordPermission
        switch perm {
        case .granted:
            completion(true)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    /// Uses SHSession.matchStreamingBuffer — feeds raw audio directly to ShazamKit
    /// for continuous matching. No SHSignatureGenerator or SHManagedSession needed.
    private func startStreamingMatch() {
        let shSession = SHSession()
        shSession.delegate = self
        self.session = shSession

        do {
            let avSession = AVAudioSession.sharedInstance()
            try avSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try avSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak shSession] buffer, time in
                shSession?.matchStreamingBuffer(buffer, at: time)
            }

            audioEngine.prepare()
            try audioEngine.start()

            // Hard timeout — stop after 15 seconds if no match
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
                guard let self, self.recognitionState == .listening else { return }
                self.stopEverything()
                self.recognitionState = .noMatch
            }

        } catch {
            stopFakeAudioAnimation()
            recognitionState = .error(error.localizedDescription)
        }
    }

    // MARK: - Match Handler

    private func handleMatch(_ match: SHMatch) {
        guard let item = match.mediaItems.first else {
            recognitionState = .noMatch
            return
        }
        let track = RecognizedTrack(from: item)
        currentTrack = track
        history.insert(track, at: 0)
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        saveHistory()
        recognitionState = .matched
    }

    // MARK: - Cleanup

    private func stopEverything() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        session = nil

        stopFakeAudioAnimation()
    }

    // MARK: - Simulated Audio Animation

    private func startFakeAudioAnimation() {
        animPhase = 0
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animPhase += 0.05
            let v = 0.3 + 0.25 * sin(self.animPhase * 4.0) + 0.15 * sin(self.animPhase * 9.3)
            self.audioLevel = Float(max(0, min(1, v)))
        }
    }

    private func stopFakeAudioAnimation() {
        animTimer?.invalidate()
        animTimer = nil
        audioLevel = 0
    }

    // MARK: - Persistence

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([RecognizedTrack].self, from: data) else { return }
        history = saved
    }
}

// MARK: - SHSessionDelegate

extension ShazamViewModel: SHSessionDelegate {

    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didFindMatch else { return }
            self.didFindMatch = true
            self.stopEverything()
            self.handleMatch(match)
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        // Streaming sends partial signatures — ignore intermediate "no match" callbacks.
        // The 15s timeout handles the real "no match" case.
    }
}
