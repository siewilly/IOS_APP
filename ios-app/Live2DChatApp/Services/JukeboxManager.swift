import Foundation
import AVFoundation
import Combine

public struct JukeboxTrack: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let fileName: String
    public let iconName: String
}

@MainActor
public final class JukeboxManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = JukeboxManager()

    @Published public var tracks: [JukeboxTrack] = [
        JukeboxTrack(id: "stay_alive", title: "Stay Alive", artist: "高橋李依 (エミリア角色曲)", fileName: "Stay_Alive", iconName: "snowflake"),
        JukeboxTrack(id: "wishing", title: "Wishing", artist: "水瀬いのり (レム角色曲)", fileName: "Wishing", iconName: "heart.fill"),
        JukeboxTrack(id: "realize", title: "Realize", artist: "鈴木このみ (Re:0 OP)", fileName: "Realize", iconName: "flame.fill")
    ]

    @Published public var currentTrackIndex: Int = 0
    @Published public var isPlaying: Bool = false
    @Published public var danceStyles: [String] = [
        "💃 偶像重拍熱舞",
        "🌸 溫柔微風漫步",
        "✨ 輕快心動搖擺",
        "❄️ 冰雪微精靈舞"
    ]
    @Published public var currentDanceStyleIndex: Int = 0

    private var audioPlayer: AVAudioPlayer?
    public var onTrackChanged: ((JukeboxTrack) -> Void)?
    public var onDanceTrigger: ((String) -> Void)?

    public var currentTrack: JukeboxTrack {
        tracks[currentTrackIndex]
    }

    public var currentDanceStyle: String {
        danceStyles[currentDanceStyleIndex]
    }

    override private init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[JukeboxManager] AudioSession setup error: \(error)")
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            playCurrent()
        }
    }

    public func playCurrent() {
        let track = currentTrack
        guard let url = Bundle.main.url(forResource: track.fileName, withExtension: "m4a") ??
                        Bundle.main.url(forResource: track.fileName, withExtension: "mp3") else {
            print("[JukeboxManager] Track file not found: \(track.fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // Infinite loop until switched
            audioPlayer?.volume = 0.85
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            onTrackChanged?(track)
            triggerDanceStep()
        } catch {
            print("[JukeboxManager] Failed to play track: \(error)")
        }
    }

    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    public func stop() {
        audioPlayer?.stop()
        isPlaying = false
    }

    public func nextTrack() {
        currentTrackIndex = (currentTrackIndex + 1) % tracks.count
        playCurrent()
    }

    public func previousTrack() {
        currentTrackIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count
        playCurrent()
    }

    public func cycleDanceStyle() {
        currentDanceStyleIndex = (currentDanceStyleIndex + 1) % danceStyles.count
        triggerDanceStep()
    }

    public func triggerDanceStep() {
        let motions = ["Happy", "Appeal", "Talk", "TapBody"]
        let motion = motions[currentDanceStyleIndex % motions.count]
        onDanceTrigger?(motion)
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.nextTrack()
        }
    }
}
