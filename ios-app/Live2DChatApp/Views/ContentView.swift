import SwiftUI

public struct ContentView: View {
    @StateObject private var configManager = ServerConfigManager.shared
    @StateObject private var networkService = ChatNetworkService.shared
    @StateObject private var lipSyncManager = NativeAudioLipSyncManager.shared
    @StateObject private var bridgeController = Live2DBridgeController()
    @StateObject private var jukebox = JukeboxManager.shared
    @StateObject private var companion = CompanionSyncService.shared
    @StateObject private var pomodoro = PomodoroManager.shared
    @ObservedObject private var authService = AuthService.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var inputText: String = ""
    @State private var isSettingsPresented: Bool = false
    @State private var isAuthPresented: Bool = false
    @State private var isControlCenterPresented: Bool = false
    @State private var isHistoryPresented: Bool = false
    @State private var isPureImmersionMode: Bool = false
    @State private var currentOutfit: String = "classic"
    @State private var touchToastText: String? = nil
    @State private var toastDismissTask: Task<Void, Never>? = nil
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

            // 3. Middle Layer: Floating translucent dialogue history & HUD
            if !isPureImmersionMode {
                VStack(spacing: 0) {
                    topNavigationBar
                        .padding(.top, 4)

                    // Companion Floating Dialogue Card
                    companionDialogueCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()

                    messageHistorySection
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.38)

                    // Horizontal Scrolling Quick Chips
                    quickChipsSection
                        .padding(.bottom, 6)

                    // Bottom Input Bar
                    bottomInputBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                // Pure Immersion Mode overlay: minimal hint
                VStack {
                    Spacer()
                    Text("🙈 純淨賞玩模式中 • 輕觸螢幕重現按鈕")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }

            // 4. Floating Touch Interaction Toast (摸頭/戳臉即時回饋)
            if let toast = touchToastText {
                VStack {
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.22, green: 0.16, blue: 0.38).opacity(0.92))
                                .overlay(Capsule().stroke(Color(red: 0.75, green: 0.60, blue: 1.0).opacity(0.4), lineWidth: 1))
                        )
                        .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 3)
                        .padding(.top, 56)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .onTapGesture {
            if isPureImmersionMode {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPureImmersionMode = false
                }
            }
        }
        .sheet(isPresented: $isControlCenterPresented) {
            EmiliaControlCenterSheet(
                jukebox: jukebox,
                companion: companion,
                pomodoro: pomodoro,
                authService: authService,
                bridgeController: bridgeController,
                currentOutfit: $currentOutfit,
                isPureImmersionMode: $isPureImmersionMode,
                onSendPrompt: { prompt in
                    handleSendPrompt(prompt)
                },
                onResetChat: {
                    networkService.startNewChat()
                },
                onOpenHistory: {
                    isHistoryPresented = true
                },
                onClose: {
                    isControlCenterPresented = false
                }
            )
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isHistoryPresented) {
            HistorySheetView(networkService: networkService) {
                isHistoryPresented = false
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
        .sheet(isPresented: $isAuthPresented) {
            AuthSheetView(mode: authService.isAuthenticated ? .profile : .login) {
                reconnectServer()
            }
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
        .onChange(of: configManager.is60FPSMode) { is60FPS in
            bridgeController.setFPSMode(is60FPS)
        }
        .onChange(of: bridgeController.isEngineReady) { isReady in
            if isReady {
                bridgeController.setFPSMode(configManager.is60FPSMode)
                bridgeController.setIntimacyScore(companion.intimacyScore)
            }
        }
        .onChange(of: companion.intimacyScore) { newScore in
            bridgeController.setIntimacyScore(newScore)
        }
    }

    // MARK: - Companion Floating Dialogue Card
    private var companionDialogueCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 5) {
                    Text("🌸")
                    Text("\(companion.levelIcon) Lv.\(companion.level) \(companion.levelName)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.pink.opacity(0.95))
                    Text("• 親密 \(Int(companion.progressToNextLevel * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Text("• \(companion.customPetName)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.70, blue: 1.0))
                }
                Spacer()
                if jukebox.isPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(Color.pink)
                        Text(jukebox.displayTitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.pink.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }

            // Latest or default dialogue prompt OR Active Thinking State!
            if networkService.isAiThinkingOrSpeaking && (networkService.messages.last?.sender == .user) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 0.85, green: 0.65, blue: 1.0))
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Color(red: 0.95, green: 0.75, blue: 1.0))
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                    Text("💭 愛蜜莉雅正在思考回覆中...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.90, green: 0.75, blue: 1.0))
                    Spacer()
                }
                .padding(.vertical, 2)
            } else if let lastAiMsg = networkService.messages.last(where: { $0.sender == .ai }) {
                Text(lastAiMsg.text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(2)
            } else {
                Text("「嗯！今天也要一起加油喔，有任何想聊的隨時告訴我～」")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.16, green: 0.11, blue: 0.28).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.75, green: 0.60, blue: 1.0).opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.purple.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 8) {
            // 1. Status Pill
            Button(action: {
                HapticManager.shared.light()
                if !networkService.isConnected {
                    reconnectServer()
                }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(networkService.isConnected ? (networkService.isAiThinkingOrSpeaking ? Color.purple : Color.green) : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(networkService.isConnected ? (networkService.isAiThinkingOrSpeaking ? "愛蜜莉雅 (思考中...)" : configManager.characterName) : networkService.connectionStatusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(networkService.isAiThinkingOrSpeaking ? Color.purple.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1))
            }

            // 2. Weather Pill (Click to broadcast briefing)
            Button(action: {
                HapticManager.shared.light()
                handleSendPrompt("愛蜜莉雅，請為我播報今天的即時天氣與最新動漫科技簡報！")
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("\(companion.weather?.city ?? "台北") \(companion.weather?.temp.map { "\(Int($0))°C" } ?? "24°C")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            Spacer()

            // 3. 💎 Diamond Floating Action Button (Opens Control Center)
            Button(action: {
                HapticManager.shared.medium()
                isControlCenterPresented = true
            }) {
                Text("💎")
                    .font(.system(size: 15))
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.65), Color.pink.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 0.85, green: 0.70, blue: 1.0).opacity(0.6), lineWidth: 1.2))
                    .shadow(color: Color.purple.opacity(0.5), radius: 6, x: 0, y: 2)
            }

            // 4. ✨ Quick Outfit Switcher
            Button(action: {
                HapticManager.shared.medium()
                currentOutfit = (currentOutfit == "classic") ? "swimsuit" : "classic"
                bridgeController.switchOutfit(currentOutfit)
                touchToastText = (currentOutfit == "classic") ? "👗 已換上：4星 經典大衣" : "👙 已換上：4星 夏日泳裝"
                dismissToastAfterDelay()
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(currentOutfit == "swimsuit" ? .pink : Color(red: 0.85, green: 0.70, blue: 1.0))
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // 5. 👁️ Pure Immersion Mode Toggle
            Button(action: {
                HapticManager.shared.rigid()
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPureImmersionMode = true
                }
            }) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // 6. Settings Button
            Button(action: {
                HapticManager.shared.light()
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

    // MARK: - Horizontal Scrolling Quick Chips
    private var quickChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 1. Stay Alive Jukebox
                chipButton(
                    label: "🎵 點歌: Stay Alive",
                    isActive: jukebox.isPlaying && jukebox.currentTrack.id == "stay_alive"
                ) {
                    jukebox.currentOnlineTrack = nil
                    jukebox.currentTrackIndex = 0
                    jukebox.togglePlayPause()
                    handleSendPrompt("愛蜜莉雅，請播放《Stay Alive》並伴隨著音樂優雅熱舞吧！")
                }

                // 2. Cycle Dance Style
                chipButton(label: "💃 切換舞步: \(jukebox.currentDanceStyle.components(separatedBy: " ").last ?? "熱舞")") {
                    jukebox.cycleDanceStyle()
                    touchToastText = "💃 已切換舞步：\(jukebox.currentDanceStyle)"
                    dismissToastAfterDelay()
                }

                // 3. Morning Briefing
                chipButton(label: "☀️ 今日晨間簡報") {
                    handleSendPrompt("愛蜜莉雅，請為我播報今天的即時天氣與最新動漫科技簡報！")
                }

                // 4. Outfit Switch
                chipButton(label: currentOutfit == "classic" ? "👗 換裝: 夏日泳裝" : "✨ 換裝: 經典大衣") {
                    currentOutfit = (currentOutfit == "classic") ? "swimsuit" : "classic"
                    bridgeController.switchOutfit(currentOutfit)
                    touchToastText = (currentOutfit == "classic") ? "👗 已換上：4星 經典大衣" : "👙 已換上：4星 夏日泳裝"
                    dismissToastAfterDelay()
                }

                // 5. Pat Head (Lv.1)
                chipButton(label: "🐾 摸摸頭") {
                    bridgeController.triggerMotion(group: "TapHead")
                    bridgeController.setExpression("exp_01_subtle_smile")
                    companion.recordInteraction(points: 2)
                    touchToastText = "✋ 輕撫銀髮，愛蜜莉雅舒服地瞇起眼睛～"
                    dismissToastAfterDelay()
                }

                // 6. Poke Cheek (Lv.1)
                chipButton(label: "😳 戳臉頰") {
                    bridgeController.triggerMotion(group: "Shy")
                    bridgeController.setExpression("exp_05_shy")
                    companion.recordInteraction(points: 2)
                    touchToastText = "😳 戳戳臉頰，愛蜜莉雅害羞地縮了下脖子！"
                    dismissToastAfterDelay()
                }

                // 7. Pull Hem (Lv.2, 80 pts)
                chipButton(label: companion.intimacyScore >= 80 ? "🌿 拉衣角" : "🔒 拉衣角 (Lv.2)") {
                    if companion.intimacyScore >= 80 {
                        bridgeController.triggerMotion(group: "TapBody")
                        bridgeController.setExpression("exp_04_smug")
                        companion.recordInteraction(points: 1)
                        touchToastText = "🌿 輕拉衣角，愛蜜莉雅轉頭溫柔地注視著你～"
                    } else {
                        HapticManager.shared.rigid()
                        bridgeController.triggerMotion(group: "Shy")
                        bridgeController.setExpression("exp_05_shy")
                        touchToastText = "🔒 需要好感度 Lv.2（信任夥伴 80分）解鎖！"
                    }
                    dismissToastAfterDelay()
                }

                // 8. Hold Hands (Lv.4, 450 pts)
                chipButton(label: companion.intimacyScore >= 450 ? "🤝 牽手" : "🔒 牽手 (Lv.4)") {
                    if companion.intimacyScore >= 450 {
                        bridgeController.triggerMotion(group: "Appeal")
                        bridgeController.setExpression("exp_21_adoration_sparkle")
                        companion.recordInteraction(points: 2)
                        touchToastText = "🤝 十指緊扣，感受掌心傳遞的溫暖，感到無比安心..."
                    } else {
                        HapticManager.shared.rigid()
                        bridgeController.triggerMotion(group: "Shy")
                        bridgeController.setExpression("exp_05_shy")
                        touchToastText = "🔒 需要好感度 Lv.4（專屬戀人 450分）解鎖！「那個……現在牽手還太害羞了啦……」"
                    }
                    dismissToastAfterDelay()
                }

                // 9. Magic Lesson
                chipButton(label: "🪄 魔法學習") {
                    handleSendPrompt("愛蜜莉雅，可以教我微精靈的冰魔法嗎？")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chipButton(label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? .pink : Color(red: 0.90, green: 0.82, blue: 1.0))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.pink.opacity(0.25) : Color(red: 0.18, green: 0.13, blue: 0.32).opacity(0.85))
                        .overlay(
                            Capsule().stroke(isActive ? Color.pink : Color(red: 0.75, green: 0.60, blue: 1.0).opacity(0.25), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
        }
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
                    HapticManager.shared.medium()
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
                TextField(networkService.isAiThinkingOrSpeaking ? "💭 愛蜜莉雅正在思考回覆中..." : "對愛蜜莉雅說點什麼...", text: $inputText)
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
                HapticManager.shared.medium()
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
        lipSyncManager.onAllPlaybackComplete = { [weak networkService] in
            networkService?.sendPlaybackComplete()
        }

        networkService.onConversationStart = { [weak lipSyncManager] in
            Task { @MainActor in
                lipSyncManager?.beginConversationTurn()
            }
        }

        networkService.onBackendSynthComplete = { [weak lipSyncManager] in
            Task { @MainActor in
                lipSyncManager?.markBackendSynthComplete()
            }
        }

        networkService.onAudioReceived = { [weak lipSyncManager] audioData, displayText, actions, rawText, expressionName, cleanText in
            Task { @MainActor in
                lipSyncManager?.enqueue(
                    audioData: audioData,
                    displayText: displayText,
                    actions: actions,
                    rawText: rawText,
                    expressionName: expressionName,
                    cleanText: cleanText
                )
            }
        }

        networkService.onExpression = { [weak bridgeController] exp in
            Task { @MainActor in
                bridgeController?.setExpression(exp)
            }
        }

        networkService.onMotion = { [weak bridgeController] motion in
            Task { @MainActor in
                bridgeController?.triggerMotion(group: motion)
            }
        }

        networkService.onInterrupt = { [weak lipSyncManager] in
            Task { @MainActor in
                lipSyncManager?.stopAll()
            }
        }

        networkService.onAuthRequired = {
            Task { @MainActor in
                await authService.autoLogin()
                if let tok = authService.token {
                    networkService.sendAuth(token: tok)
                }
            }
        }

        bridgeController.onTouchActive = { area, label, isLocked in
            Task { @MainActor in
                if isLocked {
                    HapticManager.shared.rigid()
                } else if area == "head" || area == "cheek" {
                    HapticManager.shared.light()
                } else {
                    HapticManager.shared.medium()
                }
                touchToastText = label
                dismissToastAfterDelay()
            }
        }

        bridgeController.onTouchReaction = { area, text, isLocked in
            Task { @MainActor in
                if isLocked {
                    HapticManager.shared.rigid()
                } else {
                    if area == "crystal" {
                        HapticManager.shared.rigid()
                    } else if area == "head" || area == "cheek" {
                        HapticManager.shared.light()
                    } else {
                        HapticManager.shared.medium()
                    }
                    companion.recordInteraction(points: (area == "head" || area == "cheek") ? 2 : 1)
                }
                touchToastText = text
                dismissToastAfterDelay()
            }
        }

        jukebox.onDanceTrigger = { motionGroup in
            bridgeController.triggerMotion(group: motionGroup)
        }
    }

    private func dismissToastAfterDelay() {
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    touchToastText = nil
                }
            }
        }
    }

    private func reconnectServer() {
        let wsURL = configManager.websocketURL
        networkService.connect(url: wsURL)
        Task {
            await companion.fetchCompanionState()
            await companion.fetchBriefing()
            await authService.fetchCurrentUser()
            bridgeController.setIntimacyScore(companion.intimacyScore)
        }
    }

    private func handleSendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        companion.recordInteraction(points: 1)
        networkService.sendMessage(trimmed)
    }

    private func handleSendPrompt(_ prompt: String) {
        companion.recordInteraction(points: 1)
        networkService.sendMessage(prompt)
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            lipSyncManager.stopAll()
            jukebox.pause()
            bridgeController.setPaused(true)
        case .active:
            if !configManager.isTextOnlyMode {
                bridgeController.setPaused(false)
            }
            if !networkService.isConnected {
                reconnectServer()
            }
        @unknown default:
            break
        }
    }
}
