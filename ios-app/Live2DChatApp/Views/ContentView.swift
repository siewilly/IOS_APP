import SwiftUI

public struct ContentView: View {
    @StateObject private var configManager = ServerConfigManager.shared
    @StateObject private var networkService = ChatNetworkService.shared
    @StateObject private var lipSyncManager = NativeAudioLipSyncManager.shared
    @StateObject private var bridgeController = Live2DBridgeController()

    @Environment(\.scenePhase) private var scenePhase
    @State private var inputText: String = ""
    @State private var isSettingsPresented: Bool = false
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            // 1. Deep atmospheric background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                    Color(red: 0.14, green: 0.10, blue: 0.25),
                    Color(red: 0.05, green: 0.04, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 2. Bottom Layer: Live2D WebEngine Character Canvas
            if !configManager.isTextOnlyMode {
                Live2DWebView(controller: bridgeController)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                // Text-only mode fallback placeholder
                VStack(spacing: 12) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.purple.opacity(0.6))
                    Text("省電純文字模式中\nLive2D 渲染已凍結")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.5))
                }
                .transition(.opacity)
            }

            // 3. Middle Layer: Floating translucent dialogue history
            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.top, 4)

                Spacer()

                messageHistorySection
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.45)

                bottomInputBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(
                configManager: configManager,
                networkService: networkService,
                onReconnect: {
                    reconnectServer()
                }
            )
        }
        .onAppear {
            setupServices()
            reconnectServer()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: configManager.isTextOnlyMode) { isTextOnly in
            bridgeController.setPaused(isTextOnly)
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            // Status Pill
            Button(action: {
                if !networkService.isConnected {
                    reconnectServer()
                }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(networkService.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(networkService.isConnected ? configManager.characterName : networkService.connectionStatusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }

            Spacer()

            // Text-only Mode Toggle Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    configManager.isTextOnlyMode.toggle()
                }
            }) {
                Image(systemName: configManager.isTextOnlyMode ? "bolt.slash.fill" : "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(configManager.isTextOnlyMode ? .yellow : .white.opacity(0.8))
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // Settings Button
            Button(action: {
                isSettingsPresented = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Message History
    private var messageHistorySection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(networkService.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: networkService.messages.count) { _ in
                if let last = networkService.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.15),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Bottom Input Bar
    private var bottomInputBar: some View {
        HStack(spacing: 10) {
            // If AI is thinking/speaking, provide quick interrupt action
            if networkService.isAiThinkingOrSpeaking {
                Button(action: {
                    networkService.sendInterrupt()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red.opacity(0.9))
                }
                .transition(.scale)
            }

            // Text Input Field
            HStack {
                TextField("對愛蜜莉雅說點什麼...", text: $inputText)
                    .focused($isInputFocused)
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                    .submitLabel(.send)
                    .onSubmit {
                        handleSendMessage()
                    }

                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.13, blue: 0.28).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )

            // Send Button
            Button(action: {
                handleSendMessage()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.3)
                        : Color(red: 0.70, green: 0.50, blue: 0.95)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions & Wiring
    private func setupServices() {
        lipSyncManager.bridgeController = bridgeController

        networkService.onAudioReceived = { [weak lipSyncManager] audioData, displayText, actions in
            lipSyncManager?.enqueue(audioData: audioData, displayText: displayText, actions: actions)
        }

        networkService.onExpression = { [weak bridgeController] exp in
            bridgeController?.setExpression(exp)
        }

        networkService.onMotion = { [weak bridgeController] motion in
            bridgeController?.triggerMotion(group: motion)
        }

        networkService.onInterrupt = { [weak lipSyncManager] in
            lipSyncManager?.stopAll()
        }
    }

    private func reconnectServer() {
        let wsURL = configManager.websocketURL
        networkService.connect(url: wsURL)
    }

    private func handleSendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        networkService.sendMessage(trimmed)
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            lipSyncManager.stopAll()
            bridgeController.setPaused(true)
        case .active:
            if !configManager.isTextOnlyMode {
                bridgeController.setPaused(false)
            }
        @unknown default:
            break
        }
    }
}
