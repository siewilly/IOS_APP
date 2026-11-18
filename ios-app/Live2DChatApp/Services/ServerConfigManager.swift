import Foundation
import Combine

public final class ServerConfigManager: ObservableObject {
    public static let shared = ServerConfigManager()

    private enum Keys {
        static let serverBaseURL = "server_base_url"
        static let characterName = "character_name"
        static let isTextOnlyMode = "is_text_only_mode"
        static let recentServers = "recent_server_urls"
    }

    @Published public var serverBaseURL: String {
        didSet {
            UserDefaults.standard.set(serverBaseURL, forKey: Keys.serverBaseURL)
            addToRecentServers(serverBaseURL)
        }
    }

    @Published public var characterName: String {
        didSet {
            UserDefaults.standard.set(characterName, forKey: Keys.characterName)
        }
    }

    @Published public var isTextOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(isTextOnlyMode, forKey: Keys.isTextOnlyMode)
        }
    }

    @Published public var recentServers: [String] {
        didSet {
            UserDefaults.standard.set(recentServers, forKey: Keys.recentServers)
        }
    }

    public init() {
        let savedURL = UserDefaults.standard.string(forKey: Keys.serverBaseURL) ?? "http://192.168.1.103:12393"
        let savedName = UserDefaults.standard.string(forKey: Keys.characterName) ?? "愛蜜莉雅 (Emilia)"
        let savedMode = UserDefaults.standard.bool(forKey: Keys.isTextOnlyMode)
        let savedRecents = UserDefaults.standard.stringArray(forKey: Keys.recentServers) ?? [
            "http://192.168.1.103:12393",
            "http://127.0.0.1:12393",
            "https://xxxx.trycloudflare.com"
        ]

        self.serverBaseURL = savedURL
        self.characterName = savedName
        self.isTextOnlyMode = savedMode
        self.recentServers = savedRecents
    }

    /// Derives the appropriate WebSocket connection URL (ws:// or wss://) targeting `/client-ws`
    public var websocketURL: URL? {
        var trimmed = serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Remove trailing slashes
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }

        // Scheme conversion
        if trimmed.lowercased().hasPrefix("https://") {
            trimmed = "wss://" + trimmed.dropFirst("https://".count)
        } else if trimmed.lowercased().hasPrefix("http://") {
            trimmed = "ws://" + trimmed.dropFirst("http://".count)
        } else if !trimmed.lowercased().hasPrefix("ws://") && !trimmed.lowercased().hasPrefix("wss://") {
            // Default: if domain contains cloudflare, use wss; otherwise ws
            if trimmed.contains("trycloudflare.com") {
                trimmed = "wss://" + trimmed
            } else {
                trimmed = "ws://" + trimmed
            }
        }

        // Ensure endpoint path /client-ws is present
        if !trimmed.hasSuffix("/client-ws") {
            trimmed += "/client-ws"
        }

        return URL(string: trimmed)
    }

    private func addToRecentServers(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = recentServers.filter { $0 != trimmed }
        list.insert(trimmed, at: 0)
        if list.count > 6 {
            list = Array(list.prefix(6))
        }
        recentServers = list
    }
}
