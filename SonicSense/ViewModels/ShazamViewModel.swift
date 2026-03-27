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

    // iOS 17+: managed session (handles audio capture internally)
    private var _managedSession: Any?

    // iOS 16 fallback
    private var legacySession: SHSession?
    private let audioEngine = AVAudioEngine()
    private var signatureGenerator = SHSignatureGenerator()
    private var matchTimer: Timer?
    private var timeoutTimer: Timer?

    // Simulated audio-level animation (avoids threading issues with real RMS)
    private var animTimer: Timer?
    private var animPhase: Double = 0

    private var recognitionTask: Task<Void, Never>?

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

    // MARK: - Recognition Entry Point

    private func startRecognition() {
        // Always request mic permission first, then start the appropriate session
        requestMicPermission { [weak self] granted in
            guard let self else { return }
            if granted {
                self.recognitionState = .listening
                self.startFakeAudioAnimation()
                if #available(iOS 17.0, *) {
                    self.launchManagedSession()
                } else {
                    self.performLegacySetup()
                }
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

    // MARK: - iOS 17+: SHManagedSession

    @available(iOS 17.0, *)
    private func launchManagedSession() {
        let session = SHManagedSession()
        _managedSession = session
        session.prepare()

        recognitionTask = Task { [weak self] in
            let result = await session.result()

            guard let self, !Task.isCancelled else { return }

            DispatchQueue.main.async {
                self.stopFakeAudioAnimation()
                switch result {
                case .match(let match):
                    self.handleMatch(match)
                case .noMatch(_):
                    self.recognitionState = .noMatch
                case .error(let error, _):
                    self.recognitionState = .error(error.localizedDescription)
                @unknown default:
                    self.recognitionState = .noMatch
                }
            }
        }
    }

    // MARK: - iOS 16: SHSession + AVAudioEngine

    private func performLegacySetup() {
        legacySession = SHSession()
        legacySession?.delegate = self
        signatureGenerator = SHSignatureGenerator()

        do {
            let avSession = AVAudioSession.sharedInstance()
            try avSession.setCategory(.record, mode: .measurement)
            try avSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
                try? self?.signatureGenerator.append(buffer, at: time)
            }

            audioEngine.prepare()
            try audioEngine.start()

            // Match every 4 s with accumulated audio (more audio = better match)
            matchTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                let sig = self.signatureGenerator.signature()
                self.legacySession?.match(sig)
            }

            // Hard timeout at 16 s
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 16.0, repeats: false) { [weak self] _ in
                guard let self, self.recognitionState == .listening else { return }
                self.stopEverything()
                self.recognitionState = .noMatch
            }

        } catch {
            stopFakeAudioAnimation()
            recognitionState = .error(error.localizedDescription)
        }
    }

    // MARK: - Shared Match Handler

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
        // Cancel managed session
        if #available(iOS 17.0, *) {
            (_managedSession as? SHManagedSession)?.cancel()
            _managedSession = nil
        }
        recognitionTask?.cancel()
        recognitionTask = nil

        // Stop legacy engine
        matchTimer?.invalidate(); matchTimer = nil
        timeoutTimer?.invalidate(); timeoutTimer = nil
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        legacySession = nil

        stopFakeAudioAnimation()
    }

    // MARK: - Fake Audio Level Animation

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

// MARK: - SHSessionDelegate (iOS 16 fallback only)

extension ShazamViewModel: SHSessionDelegate {

    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stopEverything()
            self.handleMatch(match)
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        // Silence intermediate "no match" callbacks — wait for the timeout
    }
}
