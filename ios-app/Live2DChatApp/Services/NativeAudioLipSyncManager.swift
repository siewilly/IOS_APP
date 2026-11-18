import Foundation
import AVFoundation
import QuartzCore

public final class NativeAudioLipSyncManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = NativeAudioLipSyncManager()

    public struct AudioQueueItem {
        public let data: Data
        public let displayText: ServerDisplayText?
        public let actions: ServerAction?
    }

    @Published public var isPlaying: Bool = false
    public weak var bridgeController: Live2DBridgeController?

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var queue: [AudioQueueItem] = []
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

    /// Enqueue an audio packet for playback and lip-syncing
    public func enqueue(audioData: Data, displayText: ServerDisplayText? = nil, actions: ServerAction? = nil) {
        let item = AudioQueueItem(data: audioData, displayText: displayText, actions: actions)
        queue.append(item)

        if audioPlayer == nil || !(audioPlayer?.isPlaying ?? false) {
            playNextInQueue()
        }
    }

    private func playNextInQueue() {
        guard !queue.isEmpty else {
            stopDisplayLink()
            bridgeController?.setMouthOpen(0.0)
            DispatchQueue.main.async {
                self.isPlaying = false
            }
            return
        }

        let item = queue.removeFirst()

        do {
            audioPlayer = try AVAudioPlayer(data: item.data)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            DispatchQueue.main.async {
                self.isPlaying = true
            }

            startDisplayLink()
        } catch {
            print("[NativeAudioLipSyncManager] Audio playback error: \(error.localizedDescription)")
            playNextInQueue()
        }
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLinkTick))
        // Target 20 FPS to minimize CPU overhead while ensuring smooth mouth movement
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 20, preferred: 20)
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

        // Apply a gentle power curve for dynamic, natural mouth aperture
        let mouthOpen = Double(pow(linear, 1.25))

        bridgeController?.setMouthOpen(mouthOpen)
    }

    // MARK: - AVAudioPlayerDelegate
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        bridgeController?.setMouthOpen(0.0)
        playNextInQueue()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[NativeAudioLipSyncManager] Audio decode error: \(String(describing: error))")
        bridgeController?.setMouthOpen(0.0)
        playNextInQueue()
    }

    /// Immediately stop all audio and cancel pending queue (e.g. user interruption or background transition)
    public func stopAll() {
        queue.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        stopDisplayLink()
        bridgeController?.setMouthOpen(0.0)
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
