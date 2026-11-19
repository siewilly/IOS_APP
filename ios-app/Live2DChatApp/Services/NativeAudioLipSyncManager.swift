import Foundation
import AVFoundation
import QuartzCore

@MainActor
public final class NativeAudioLipSyncManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = NativeAudioLipSyncManager()

    public struct AudioQueueItem {
        public let data: Data
        public let displayText: ServerDisplayText?
        public let actions: ServerAction?
        public let rawText: String?
        public let expressionName: String?
        public let cleanText: String?

        public init(
            data: Data,
            displayText: ServerDisplayText? = nil,
            actions: ServerAction? = nil,
            rawText: String? = nil,
            expressionName: String? = nil,
            cleanText: String? = nil
        ) {
            self.data = data
            self.displayText = displayText
            self.actions = actions
            self.rawText = rawText
            self.expressionName = expressionName
            self.cleanText = cleanText
        }
    }

    @Published public var isPlaying: Bool = false
    public weak var bridgeController: Live2DBridgeController?
    public var onAllPlaybackComplete: (() -> Void)?

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var queue: [AudioQueueItem] = []
    private var backendSynthComplete: Bool = false
    private var fallbackIdleWorkItem: DispatchWorkItem?
    private let silenceThresholdDB: Float = -45.0

    public override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("[NativeAudioLipSyncManager] AudioSession setup error: \(error.localizedDescription)")
        }
    }

    /// Reset turn state when a new conversation chain starts
    public func beginConversationTurn() {
        backendSynthComplete = false
        fallbackIdleWorkItem?.cancel()
        fallbackIdleWorkItem = nil
    }

    /// Called when server sends `backend-synth-complete` (exact desktop pet parity)
    public func markBackendSynthComplete() {
        backendSynthComplete = true
        checkAndFinalizePlayback()
    }

    /// Enqueue an audio packet for playback, Desktop-Pet-parity motion orchestration, and lip-syncing
    public func enqueue(
        audioData: Data,
        displayText: ServerDisplayText? = nil,
        actions: ServerAction? = nil,
        rawText: String? = nil,
        expressionName: String? = nil,
        cleanText: String? = nil
    ) {
        fallbackIdleWorkItem?.cancel()
        fallbackIdleWorkItem = nil

        let item = AudioQueueItem(
            data: audioData,
            displayText: displayText,
            actions: actions,
            rawText: rawText ?? displayText?.text,
            expressionName: expressionName,
            cleanText: cleanText
        )
        queue.append(item)

        if audioPlayer == nil || !(audioPlayer?.isPlaying ?? false) {
            playNextInQueue()
        }
    }

    private func playNextInQueue() {
        guard !queue.isEmpty else {
            stopDisplayLink()
            bridgeController?.setMouthOpen(0.0)
            self.isPlaying = false

            // DO NOT abruptly reset to Idle between chunks!
            // Only finalize & settle smoothly once the ENTIRE turn finishes (backend-synth-complete + queue empty).
            if backendSynthComplete {
                checkAndFinalizePlayback()
            } else {
                // Safety net if server never sends backend-synth-complete (e.g. network hiccup)
                let fallback = DispatchWorkItem { [weak self] in
                    guard let self = self, !self.isPlaying, self.queue.isEmpty else { return }
                    self.bridgeController?.onPlaybackComplete()
                }
                fallbackIdleWorkItem = fallback
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: fallback)
            }
            return
        }

        fallbackIdleWorkItem?.cancel()
        fallbackIdleWorkItem = nil

        let item = queue.removeFirst()

        do {
            let player = try AVAudioPlayer(data: item.data)
            player.delegate = self
            player.isMeteringEnabled = true
            player.prepareToPlay()
            self.audioPlayer = player

            // 1. Apply synchronized facial expression at the exact moment this chunk starts playing
            if let exp = item.expressionName, !exp.isEmpty {
                bridgeController?.setExpression(exp)
            }

            // 2. Drive Desktop-Pet-parity multi-tag motion orchestrator with exact audio duration!
            let durationMs = Int(player.duration * 1000.0)
            bridgeController?.onChunkStart(rawText: item.rawText ?? "", durationMs: durationMs)

            player.play()
            self.isPlaying = true
            startDisplayLink()
        } catch {
            print("[NativeAudioLipSyncManager] Audio playback error: \(error.localizedDescription)")
            playNextInQueue()
        }
    }

    private func checkAndFinalizePlayback() {
        guard backendSynthComplete, queue.isEmpty, !isPlaying else { return }
        backendSynthComplete = false
        fallbackIdleWorkItem?.cancel()
        fallbackIdleWorkItem = nil

        // Notify backend (`frontend-playback-complete`) and let WebEngine smoothly settle to Idle
        onAllPlaybackComplete?()
        bridgeController?.onPlaybackComplete()
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLinkTick))
        // 30 FPS gives responsive vowel lip-sync and accurate speech-gesture stress beat detection
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLinkTick() {
        guard let player = audioPlayer, player.isPlaying else {
            bridgeController?.setMouthOpen(0.0)
            return
        }

        player.updateMeters()
        let avgPower = player.averagePower(forChannel: 0) // range: -160.0 dB to 0.0 dB

        // Linear interpolation from silence threshold to 0 dB peak
        let clamped = max(silenceThresholdDB, min(0.0, avgPower))
        let linear = (clamped - silenceThresholdDB) / (-silenceThresholdDB) // 0.0 ... 1.0

        // Natural acoustic scaling (matching desktop pet lipSyncScale = 1.25)
        let mouthOpen = min(1.0, Double(pow(linear, 1.15)) * 1.15)
        bridgeController?.setMouthOpen(mouthOpen)
    }

    // MARK: - AVAudioPlayerDelegate
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.bridgeController?.setMouthOpen(0.0)
            self.playNextInQueue()
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[NativeAudioLipSyncManager] Audio decode error: \(String(describing: error))")
        Task { @MainActor in
            self.bridgeController?.setMouthOpen(0.0)
            self.playNextInQueue()
        }
    }

    /// Immediately stop all audio and cancel pending queue (e.g. user interruption or background transition)
    public func stopAll() {
        queue.removeAll()
        backendSynthComplete = false
        fallbackIdleWorkItem?.cancel()
        fallbackIdleWorkItem = nil
        audioPlayer?.stop()
        audioPlayer = nil
        stopDisplayLink()
        bridgeController?.setMouthOpen(0.0)
        bridgeController?.onInterrupt()
        self.isPlaying = false
    }
}
