import Foundation
import Combine

public final class ChatNetworkService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    public static let shared = ChatNetworkService()

    @Published public var isConnected: Bool = false
    @Published public var connectionStatusText: String = "未連線"
    @Published public var messages: [ChatMessage] = []
    @Published public var isAiThinkingOrSpeaking: Bool = false
    @Published public var isAuthRequired: Bool = false

    // Event hooks for audio playback and Live2D triggers
    public var onAudioReceived: ((Data, ServerDisplayText?, ServerAction?, String?, String?, String?) -> Void)?
    public var onExpression: ((String) -> Void)?
    public var onMotion: ((String) -> Void)?
    public var onInterrupt: (() -> Void)?
    public var onAuthRequired: (() -> Void)?
    public var onConversationStart: (() -> Void)?
    public var onBackendSynthComplete: (() -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var currentURL: URL?
    private var reconnectWorkItem: DispatchWorkItem?

    public func scheduleReconnect() {
        guard !isConnected else { return }
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isConnected, let url = self.currentURL else { return }
            print("[ChatNetworkService] Auto-reconnecting to: \(url.absoluteString)")
            self.connect(url: url)
        }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    public func connect(url: URL?) {
        guard let url = url else {
            DispatchQueue.main.async {
                self.connectionStatusText = "伺服器網址無效"
                self.isConnected = false
            }
            return
        }

        disconnect()
        reconnectWorkItem?.cancel()
        self.currentURL = url

        DispatchQueue.main.async {
            self.connectionStatusText = "連線中..."
            self.isConnected = false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let task = session?.webSocketTask(with: request)
        self.webSocketTask = task
        task?.resume()

        listenForMessages()
        startPingTimer()
    }

    public func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatusText = "已斷線"
            self.isAiThinkingOrSpeaking = false
        }
    }

    public func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // If AI is currently replying, interrupt first
        if isAiThinkingOrSpeaking {
            sendInterrupt()
        }

        // Append user message immediately to the message list
        let userMessage = ChatMessage(sender: .user, text: trimmed)
        DispatchQueue.main.async {
            self.messages.append(userMessage)
            self.isAiThinkingOrSpeaking = true
        }

        let payload: [String: Any] = [
            "type": "text-input",
            "text": trimmed,
            "images": []
        ]
        sendJSON(payload)
    }

    public func sendInterrupt() {
        let payload: [String: Any] = [
            "type": "interrupt-signal",
            "text": ""
        ]
        sendJSON(payload)
        DispatchQueue.main.async {
            self.isAiThinkingOrSpeaking = false
            self.onInterrupt?()
        }
    }

    public func startNewChat() {
        sendInterrupt()
        sendJSON(["type": "create-new-history"])
        DispatchQueue.main.async {
            self.messages.removeAll()
        }
    }

    private func sendHandshake() {
        sendJSON(["type": "fetch-configs"])
        sendJSON(["type": "fetch-history-list"])
        sendJSON(["type": "create-new-history"])
    }

    public func sendAuth(token: String) {
        sendJSON(["type": "auth", "token": token])
    }

    public func sendPlaybackComplete() {
        sendJSON(["type": "frontend-playback-complete"])
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("[ChatNetworkService] Send error: \(error.localizedDescription)")
            }
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("[ChatNetworkService] Receive failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.connectionStatusText = "連線異常中斷"
                    self.isAiThinkingOrSpeaking = false
                    self.scheduleReconnect()
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingText(text)
                case .data(let data):
                    if let str = String(data: data, encoding: .utf8) {
                        self.handleIncomingText(str)
                    }
                @unknown default:
                    break
                }
                // Continue listening loop
                self.listenForMessages()
            }
        }
    }

    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        DispatchQueue.main.async {
            switch type {
            case "auth-required":
                self.isAuthRequired = true
                Task {
                    await AuthService.shared.autoLogin()
                    if let tok = AuthService.shared.token {
                        self.sendAuth(token: tok)
                    }
                }

            case "auth-success":
                self.isAuthRequired = false
                self.isConnected = true
                self.connectionStatusText = "已連線"
                self.sendHandshake()
                if let userDict = json["user"] as? [String: Any],
                   let id = userDict["id"] as? Int,
                   let uname = userDict["username"] as? String {
                    let dName = userDict["display_name"] as? String ?? uname
                    let cName = userDict["emilia_callname"] as? String ?? ""
                    AuthService.shared.currentUser = UserProfile(id: id, username: uname, display_name: dName, emilia_callname: cName)
                }
                if let state = json["companion_state"] as? [String: Any] {
                    CompanionSyncService.shared.applyState(state)
                }

            case "full-text":
                if let msgText = json["text"] as? String {
                    if msgText.contains("Connection established") {
                        self.isConnected = true
                        self.connectionStatusText = "已連線"
                        self.sendHandshake()
                    }
                }

            case "control":
                if let control = json["text"] as? String {
                    self.handleControlMessage(control)
                }

            case "audio":
                self.handleAudioMessage(json: json, rawData: data)

            case "backend-synth-complete":
                self.onBackendSynthComplete?()

            case "history-data":
                if let messagesArr = json["messages"] as? [[String: Any]] {
                    self.handleHistoryData(messagesArr)
                }

            case "error":
                if let errMsg = json["message"] as? String {
                    let sysMsg = ChatMessage(sender: .system, text: "伺服器錯誤: \(errMsg)")
                    self.messages.append(sysMsg)
                }

            default:
                break
            }
        }
    }

    private func handleControlMessage(_ control: String) {
        switch control {
        case "conversation-chain-start":
            self.isAiThinkingOrSpeaking = true
            self.onConversationStart?()
        case "conversation-chain-end":
            self.isAiThinkingOrSpeaking = false
        case "interrupt":
            self.isAiThinkingOrSpeaking = false
            self.onInterrupt?()
        default:
            break
        }
    }

    public struct ParsedTags {
        public let motionGroup: String?
        public let expressionName: String?
        public let cleanText: String
    }

    public static func parseTags(from text: String) -> ParsedTags {
        var motionGroup: String? = nil
        var expressionName: String? = nil

        // 1. Extract motion tag: [motion:xxx]
        if let regex = try? NSRegularExpression(pattern: "\\[motion:([a-zA-Z0-9_-]+)\\]", options: .caseInsensitive) {
            let nsStr = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                let tag = nsStr.substring(with: match.range(at: 1)).lowercased()
                motionGroup = mapMotionTagToGroup(tag)
            }
        }

        // 2. Extract expression tag: [smile], [shy], [pout], [thinking], [joy], etc.
        if let regex = try? NSRegularExpression(pattern: "\\[([a-zA-Z0-9_-]+)\\]", options: .caseInsensitive) {
            let nsStr = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsStr.length))
            for m in matches {
                let tag = nsStr.substring(with: m.range(at: 1)).lowercased()
                if !tag.hasPrefix("motion:") {
                    if let exp = mapExpressionTag(tag) {
                        expressionName = exp
                        break
                    }
                }
            }
        }

        // If motionGroup is not set, derive from expression
        if motionGroup == nil, let exp = expressionName {
            motionGroup = mapExpressionToMotion(exp)
        }

        // 3. Clean all bracket tags like [motion:talk], [smile], [shy], etc.
        let clean = text.replacingOccurrences(of: "\\[[a-zA-Z0-9_:-]+\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedTags(motionGroup: motionGroup, expressionName: expressionName, cleanText: clean)
    }

    public static func mapMotionTagToGroup(_ tag: String) -> String {
        let t = tag.lowercased()
        if t.contains("jump") || t.contains("跳") {
            return "Happy"
        } else if t.contains("appeal") || t.contains("撒嬌") || t.contains("love") || t.contains("adoration") {
            return "Appeal"
        } else if t.contains("shysmile") || t.contains("嬌羞") {
            return "ShySmile"
        } else if t.contains("shy") || t.contains("害羞") || t.contains("blush") || t.contains("shame") {
            return "Shy"
        } else if t.contains("think") || t.contains("思考") || t.contains("puzzle") || t.contains("doubt") {
            return "Thinking"
        } else if t.contains("pout") || t.contains("angry") || t.contains("氣惱") || t.contains("anger") {
            return "Angry"
        } else if t.contains("pride") || t.contains("自豪") || t.contains("smug") {
            return "Pride"
        } else if t.contains("serious") || t.contains("嚴肅") || t.contains("認真") {
            return "Serious"
        } else if t.contains("sad") || t.contains("哀傷") || t.contains("cry") || t.contains("tears") || t.contains("upset") {
            return "Sad"
        } else if t.contains("surprise") || t.contains("shock") || t.contains("驚") {
            return "Surprise"
        } else if t.contains("happy") || t.contains("joy") || t.contains("smile") || t.contains("雀躍") {
            return "Happy"
        } else if t.contains("idle") || t.contains("wait") || t.contains("待機") {
            return "Idle"
        } else {
            return "Talk"
        }
    }

    public static func mapExpressionTag(_ tag: String) -> String? {
        let t = tag.lowercased()
        if t.contains("smile") || t.contains("笑") {
            return "exp_01_subtle_smile"
        } else if t.contains("joy") || t.contains("happy") || t.contains("開懷") || t.contains("大笑") {
            return "exp_02_happy_big"
        } else if t.contains("wink") || t.contains("眨眼") {
            return "exp_03_wink"
        } else if t.contains("smug") || t.contains("pride") || t.contains("得意") || t.contains("自豪") {
            return "exp_04_smug"
        } else if t.contains("blush") || t.contains("臉紅") {
            return "exp_06_blushing_heavy"
        } else if t.contains("shy") || t.contains("害羞") {
            return "exp_05_shy"
        } else if t.contains("pout") || t.contains("鼓嘴") || t.contains("嘟嘴") {
            return "exp_07_pout"
        } else if t.contains("jitome") || t.contains("白眼") || t.contains("鄙視") {
            return "exp_08_jitome"
        } else if t.contains("think") || t.contains("思考") || t.contains("puzzle") {
            return "exp_09_thinking"
        } else if t.contains("shock") || t.contains("震驚") {
            return "exp_11_shocked"
        } else if t.contains("surprise") || t.contains("驚奇") || t.contains("吃驚") {
            return "exp_10_surprise"
        } else if t.contains("cry") || t.contains("哭") || t.contains("流淚") {
            return "exp_12_cry"
        } else if t.contains("sad") || t.contains("難過") || t.contains("傷心") {
            return "exp_14_sad"
        } else if t.contains("angry") || t.contains("anger") || t.contains("生氣") {
            return "exp_15_angry"
        } else if t.contains("serious") || t.contains("嚴肅") {
            return "exp_17_serious"
        } else if t.contains("love") || t.contains("adoration") || t.contains("愛慕") {
            return "exp_21_adoration_sparkle"
        } else if t.contains("tsundere") || t.contains("傲嬌") {
            return "exp_23_tsundere_blush"
        } else if t.contains("neutral") || t.contains("idle") || t.contains("平靜") {
            return "exp_00_neutral"
        }
        return nil
    }

    public static func mapExpressionToMotion(_ exp: String) -> String {
        switch exp {
        case "exp_02_happy_big":
            return "Happy"
        case "exp_04_smug":
            return "Pride"
        case "exp_05_shy", "exp_06_blushing_heavy", "exp_23_tsundere_blush":
            return "Shy"
        case "exp_07_pout", "exp_15_angry":
            return "Angry"
        case "exp_09_thinking":
            return "Thinking"
        case "exp_10_surprise", "exp_11_shocked":
            return "Surprise"
        case "exp_12_cry", "exp_14_sad":
            return "Sad"
        case "exp_17_serious":
            return "Serious"
        case "exp_21_adoration_sparkle":
            return "Appeal"
        default:
            return "Talk"
        }
    }

    private func handleAudioMessage(json: [String: Any], rawData: Data) {
        // Decode ServerAudioPayload (ServerAction now handles both Int and String expressions!)
        guard let payload = try? JSONDecoder().decode(ServerAudioPayload.self, from: rawData) else {
            print("[ChatNetworkService] Failed to decode ServerAudioPayload")
            return
        }

        let rawText = payload.display_text?.text ?? ""
        var expressionName: String? = payload.actions?.expressions?.first
        var cleanedText: String = ""
        var fallbackMotionGroup: String? = payload.actions?.motions?.first

        // 1. Text display sanitization & fallback tag extraction
        if !rawText.isEmpty {
            let tags = ChatNetworkService.parseTags(from: rawText)
            if expressionName == nil {
                expressionName = tags.expressionName
            }
            if fallbackMotionGroup == nil {
                fallbackMotionGroup = tags.motionGroup
            }
            cleanedText = tags.cleanText

            let aiName = payload.display_text?.name ?? "愛蜜莉雅"
            if !cleanedText.isEmpty {
                let aiMessage = ChatMessage(sender: .ai, text: cleanedText, name: aiName)
                self.messages.append(aiMessage)
            }
        }

        // 2. Audio decoding: defer expression & multi-tag motion execution to exact chunk playback start!
        if let base64Audio = payload.audio,
           !base64Audio.isEmpty,
           let audioBytes = Data(base64Encoded: base64Audio) {
            self.isAiThinkingOrSpeaking = true
            self.onAudioReceived?(audioBytes, payload.display_text, payload.actions, rawText, expressionName, cleanedText)
        } else {
            // Silent text-only payload fallback
            if let exp = expressionName {
                self.onExpression?(exp)
            }
            if let motion = fallbackMotionGroup {
                self.onMotion?(motion)
            }
        }
    }

    private func handleHistoryData(_ historyArr: [[String: Any]]) {
        var restored: [ChatMessage] = []
        for item in historyArr {
            guard let role = item["role"] as? String,
                  let content = item["content"] as? String else { continue }
            let sender: MessageSender = (role == "human" || role == "user") ? .user : .ai
            let cleanContent = sender == .ai ? ChatNetworkService.parseTags(from: content).cleanText : content
            if !cleanContent.isEmpty {
                restored.append(ChatMessage(sender: sender, text: cleanContent))
            }
        }
        if !restored.isEmpty {
            self.messages = restored
        }
    }

    private func startPingTimer() {
        stopPingTimer()
        // Send a ping every 20 seconds to prevent Cloudflare tunnel timeout
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if let error = error {
                    print("[ChatNetworkService] Ping error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - URLSessionWebSocketDelegate
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatusText = "已連線"
            self.sendHandshake()
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatusText = "連線已關閉"
            self.isAiThinkingOrSpeaking = false
            self.scheduleReconnect()
        }
    }
}
