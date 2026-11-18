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
    @Published public var currentOnlineTrack: OnlineMusicTrack? = nil
    @Published public var isPlaying: Bool = false
    @Published public var danceStyles: [String] = [
        "💃 偶像重拍熱舞",
        "🌸 溫柔微風漫步",
        "✨ 輕快心動搖擺",
        "❄️ 冰雪微精靈舞"
    ]
    @Published public var currentDanceStyleIndex: Int = 0

    private var localPlayer: AVAudioPlayer?
    private var streamPlayer: AVPlayer?
    public var onTrackChanged: ((String) -> Void)?
    public var onDanceTrigger: ((String) -> Void)?

    public var currentTrack: JukeboxTrack {
        tracks[currentTrackIndex]
    }

    public var displayTitle: String {
        if let online = currentOnlineTrack {
            return online.title
        }
        return tracks[currentTrackIndex].title
    }

    public var displayArtist: String {
        if let online = currentOnlineTrack {
            return online.artist
        }
        return tracks[currentTrackIndex].artist
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
            if currentOnlineTrack != nil {
                resumeOnline()
            } else {
                playCurrent()
            }
        }
    }

    public func playCurrent() {
        currentOnlineTrack = nil
        streamPlayer?.pause()
        streamPlayer = nil

        let track = tracks[currentTrackIndex]
        guard let url = Bundle.main.url(forResource: track.fileName, withExtension: "m4a") ??
                        Bundle.main.url(forResource: track.fileName, withExtension: "mp3") else {
            print("[JukeboxManager] Track file not found: \(track.fileName)")
            return
        }

        do {
            localPlayer = try AVAudioPlayer(contentsOf: url)
            localPlayer?.delegate = self
            localPlayer?.numberOfLoops = -1
            localPlayer?.volume = 0.85
            localPlayer?.prepareToPlay()
            localPlayer?.play()
            isPlaying = true
            onTrackChanged?(track.title)
            triggerDanceStep()
        } catch {
            print("[JukeboxManager] Failed to play track: \(error)")
        }
    }

    public func playOnlineTrack(_ track: OnlineMusicTrack) {
        localPlayer?.stop()
        localPlayer = nil

        currentOnlineTrack = track
        let base = ServerConfigManager.shared.serverBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var streamUrlStr = track.stream_url ?? ""
        if streamUrlStr.starts(with: "/") {
            streamUrlStr = "\(base)\(streamUrlStr)"
        }

        guard let url = URL(string: streamUrlStr) else { return }
        streamPlayer = AVPlayer(url: url)
        streamPlayer?.volume = 0.85
        streamPlayer?.play()
        isPlaying = true
        onTrackChanged?(track.title)
        triggerDanceStep()
    }

    public func resumeOnline() {
        streamPlayer?.play()
        isPlaying = true
        triggerDanceStep()
    }

    public func pause() {
        localPlayer?.pause()
        streamPlayer?.pause()
        isPlaying = false
    }

    public func stop() {
        localPlayer?.stop()
        streamPlayer?.pause()
        streamPlayer = nil
        isPlaying = false
    }

    public func nextTrack() {
        currentOnlineTrack = nil
        currentTrackIndex = (currentTrackIndex + 1) % tracks.count
        playCurrent()
    }

    public func previousTrack() {
        currentOnlineTrack = nil
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
