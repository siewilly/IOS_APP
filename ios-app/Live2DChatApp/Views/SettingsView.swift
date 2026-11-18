import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var configManager: ServerConfigManager
    @ObservedObject public var networkService: ChatNetworkService
    public var onReconnect: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var serverInput: String = ""
    @State private var characterInput: String = ""

    public init(
        configManager: ServerConfigManager,
        networkService: ChatNetworkService,
        onReconnect: @escaping () -> Void
    ) {
        self.configManager = configManager
        self.networkService = networkService
        self.onReconnect = onReconnect
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("伺服器連線設定 (Cloudflare / 本地端)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("後端伺服器網址 (HTTP / HTTPS)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如 https://xxxx.trycloudflare.com", text: $serverInput)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    if let wsURL = configManager.websocketURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("解析後的 WebSocket 終端:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(wsURL.absoluteString)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.purple)
                        }
                    }

                    HStack {
                        Circle()
                            .fill(networkService.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(networkService.connectionStatusText)
                            .font(.subheadline)
                        Spacer()
                        Button("儲存並重新連線") {
                            configManager.serverBaseURL = serverInput
                            onReconnect()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.55, green: 0.35, blue: 0.85))
                    }
                }

                Section(header: Text("常用網址快捷鍵")) {
                    Button("本地測試 (127.0.0.1:12393)") {
                        serverInput = "http://127.0.0.1:12393"
                    }
                    Button("區域網路 (192.168.1.100:12393)") {
                        serverInput = "http://192.168.1.100:12393"
                    }
                    ForEach(configManager.recentServers, id: \.self) { url in
                        Button(url) {
                            serverInput = url
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section(header: Text("角色與外觀")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("伴侶稱號")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("愛蜜莉雅 (Emilia)", text: $characterInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                Section(header: Text("電源與效能優化")) {
                    Toggle("極致省電 / 純文字模式", isOn: $configManager.isTextOnlyMode)
                    Text("開啟後將隱藏並凍結 Live2D 畫布與 WebGL 渲染管線，只保留原生文字對話，達到零 GPU 消耗。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("架構說明")) {
                    Text("• 畫面渲染：本地 WKWebView 專責 Live2D，強制鎖定 12~30 FPS、解析度倍率 1x。\n• 網路音訊：原生 Swift URLSession 與 AVAudioPlayer 硬體解碼。\n• 嘴型同步：原生 CADisplayLink 即時讀取振幅轉換 ParamMouthOpenY。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("連線與系統設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        configManager.serverBaseURL = serverInput
                        configManager.characterName = characterInput
                        dismiss()
                    }
                }
            }
            .onAppear {
                serverInput = configManager.serverBaseURL
                characterInput = configManager.characterName
            }
        }
    }
}
