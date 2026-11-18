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
    public var onAudioReceived: ((Data, ServerDisplayText?, ServerAction?) -> Void)?
    public var onExpression: ((String) -> Void)?
    public var onMotion: ((String) -> Void)?
    public var onInterrupt: (() -> Void)?
    public var onAuthRequired: (() -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var currentURL: URL?

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
                self.connectionStatusText = "需要登入帳號"
                self.onAuthRequired?()

            case "auth-success":
                self.isAuthRequired = false
                self.isConnected = true
                self.connectionStatusText = "已連線"
                self.sendHandshake()

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
        case "conversation-chain-end":
            self.isAiThinkingOrSpeaking = false
        case "interrupt":
            self.isAiThinkingOrSpeaking = false
            self.onInterrupt?()
        default:
            break
        }
    }

    private func handleAudioMessage(json: [String: Any], rawData: Data) {
        // Decode ServerAudioPayload
        guard let payload = try? JSONDecoder().decode(ServerAudioPayload.self, from: rawData) else {
            return
        }

        // 1. Text display update
        if let displayText = payload.display_text, let text = displayText.text, !text.isEmpty {
            let aiName = displayText.name ?? "愛蜜莉雅"
            // Append or update message
            let aiMessage = ChatMessage(sender: .ai, text: text, name: aiName)
            self.messages.append(aiMessage)
        }

        // 2. Action triggers (expressions & motions)
        if let actions = payload.actions {
            if let expressions = actions.expressions, let firstExp = expressions.first {
                self.onExpression?(firstExp)
            }
            if let motions = actions.motions, let firstMotion = motions.first {
                self.onMotion?(firstMotion)
            }
        }

        // 3. Audio decoding for native lip sync
        if let base64Audio = payload.audio,
           let audioBytes = Data(base64Encoded: base64Audio) {
            self.isAiThinkingOrSpeaking = true
            self.onAudioReceived?(audioBytes, payload.display_text, payload.actions)
        }
    }

    private func handleHistoryData(_ historyArr: [[String: Any]]) {
        var restored: [ChatMessage] = []
        for item in historyArr {
            guard let role = item["role"] as? String,
                  let content = item["content"] as? String else { continue }
            let sender: MessageSender = (role == "human" || role == "user") ? .user : .ai
            restored.append(ChatMessage(sender: sender, text: content))
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
        }
    }
}
