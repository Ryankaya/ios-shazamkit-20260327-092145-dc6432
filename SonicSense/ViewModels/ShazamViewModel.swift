import Foundation
import ShazamKit
import AVFoundation
import Combine

// MARK: - ShazamViewModel

final class ShazamViewModel: NSObject, ObservableObject {

    // MARK: - Published

    @Published private(set) var recognitionState: RecognitionState = .idle
    @Published private(set) var currentTrack: RecognizedTrack?
    @Published private(set) var history: [RecognizedTrack] = []
    @Published private(set) var audioLevel: Float = 0

    // MARK: - Private

    private let session = SHSession()
    private let audioEngine = AVAudioEngine()
    private var signatureGenerator = SHSignatureGenerator()
    private var matchTimer: Timer?

    private let historyKey = "com.ryankaya.sonicsense.history"
    private let maxHistoryItems = 100
    private let listeningDuration: TimeInterval = 10

    // MARK: - Init

    override init() {
        super.init()
        session.delegate = self
        loadHistory()
    }

    // MARK: - Public Interface

    func toggleListening() {
        switch recognitionState {
        case .idle, .noMatch, .error:
            requestPermissionAndStart()
        case .listening:
            stopListening(transitionTo: .idle)
        default:
            break
        }
    }

    func resetState() {
        stopListening(transitionTo: .idle)
        currentTrack = nil
    }

    func deleteHistoryItem(_ track: RecognizedTrack) {
        history.removeAll { $0.id == track.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    // MARK: - Permission & Audio Setup

    private func requestPermissionAndStart() {
        let status = AVAudioSession.sharedInstance().recordPermission
        switch status {
        case .granted:
            startListening()
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startListening()
                    } else {
                        self?.recognitionState = .error(RecognitionError.microphoneAccessDenied.localizedDescription ?? "")
                    }
                }
            }
        case .denied:
            recognitionState = .error(RecognitionError.microphoneAccessDenied.localizedDescription ?? "")
        @unknown default:
            break
        }
    }

    private func startListening() {
        signatureGenerator = SHSignatureGenerator()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 8192, format: recordingFormat) { [weak self] buffer, audioTime in
                try? self?.signatureGenerator.append(buffer, at: audioTime)
                let level = Self.computeRMSLevel(buffer: buffer)
                DispatchQueue.main.async { self?.audioLevel = level }
            }

            audioEngine.prepare()
            try audioEngine.start()

            recognitionState = .listening

            matchTimer = Timer.scheduledTimer(withTimeInterval: listeningDuration, repeats: false) { [weak self] _ in
                self?.performMatch()
            }

        } catch {
            recognitionState = .error(error.localizedDescription)
        }
    }

    private func performMatch() {
        let signature = signatureGenerator.signature()
        tearDownAudioEngine()
        recognitionState = .processing
        session.match(signature: signature)
    }

    private func stopListening(transitionTo state: RecognitionState) {
        matchTimer?.invalidate()
        matchTimer = nil
        tearDownAudioEngine()
        recognitionState = state
    }

    private func tearDownAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Audio Utilities

    private static func computeRMSLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameLength { sum += channelData[i] * channelData[i] }
        let rms = sqrt(sum / Float(frameLength))
        return min(rms * 20, 1.0)
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
        guard let item = match.mediaItems.first else { return }
        let track = RecognizedTrack(from: item)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentTrack = track
            self.history.insert(track, at: 0)
            if self.history.count > self.maxHistoryItems {
                self.history = Array(self.history.prefix(self.maxHistoryItems))
            }
            self.saveHistory()
            self.recognitionState = .matched
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.recognitionState = .noMatch
        }
    }
}
