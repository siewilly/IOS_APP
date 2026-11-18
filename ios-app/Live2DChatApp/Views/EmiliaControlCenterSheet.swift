import SwiftUI

public struct EmiliaControlCenterSheet: View {
    @ObservedObject var jukebox: JukeboxManager
    @ObservedObject var companion: CompanionSyncService
    @ObservedObject var pomodoro: PomodoroManager
    @ObservedObject var authService: AuthService
    var bridgeController: Live2DBridgeController?

    @Binding var currentOutfit: String
    @Binding var isPureImmersionMode: Bool

    var onSendPrompt: (String) -> Void
    var onResetChat: () -> Void
    var onOpenHistory: () -> Void
    var onClose: () -> Void

    @State private var isIntimacyDetailPresented: Bool = false
    @State private var isProfileEditPresented: Bool = false
    @State private var musicSearchQuery: String = ""
    @State private var searchResults: [OnlineMusicTrack] = []
    @State private var isSearchingMusic: Bool = false
    @State private var editingCallname: String = ""
    @State private var toastMessage: String? = nil

    public init(
        jukebox: JukeboxManager,
        companion: CompanionSyncService,
        pomodoro: PomodoroManager = PomodoroManager.shared,
        authService: AuthService = AuthService.shared,
        bridgeController: Live2DBridgeController? = nil,
        currentOutfit: Binding<String>,
        isPureImmersionMode: Binding<Bool>,
        onSendPrompt: @escaping (String) -> Void,
        onResetChat: @escaping () -> Void = {},
        onOpenHistory: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.jukebox = jukebox
        self.companion = companion
        self.pomodoro = pomodoro
        self.authService = authService
        self.bridgeController = bridgeController
        self._currentOutfit = currentOutfit
        self._isPureImmersionMode = isPureImmersionMode
        self.onSendPrompt = onSendPrompt
        self.onResetChat = onResetChat
        self.onOpenHistory = onOpenHistory
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Dark luxury glass background
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.08, blue: 0.20),
                    Color(red: 0.06, green: 0.04, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header
                HStack {
                    HStack(spacing: 8) {
                        Text("💎")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("愛蜜莉雅 靈動控制台")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Re:從零開始的異世界生活 · 旗艦桌面伴侶")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.75, green: 0.60, blue: 1.0))
                        }
                    }

                    Spacer()

                    Button(action: {
                        HapticManager.shared.light()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.12))

                // Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Card 0: 👤 伴侶身份與個人設定 (有栖)
                        userProfileCard

                        // Card 1: 💖 戀人好感羈絆中樞 (直連 SQLite)
                        intimacyCard

                        // Card 2: 🎵 線上即時搜歌點唱機 & 旋律熱舞
                        jukeboxCard

                        // Card 3: 👗 角色換裝 · 衣櫥 (雙造型熱切換)
                        wardrobeCard

                        // Card 4: 🌦️ 聯網智慧簡報 (天氣與頭條)
                        briefingCard

                        // Card 5: 🪄 桌寵日常伴侶實用工具 (番茄鐘、話題重置、歷史記憶錄)
                        utilitiesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }

            // Toast feedback
            if let toast = toastMessage {
                VStack {
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.pink.opacity(0.92)))
                        .shadow(radius: 6)
                        .padding(.top, 56)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            Task {
                await companion.fetchCompanionState()
                await companion.fetchBriefing()
                await authService.fetchCurrentUser()
            }
        }
        .sheet(isPresented: $isIntimacyDetailPresented) {
            IntimacyHubDetailSheet(
                companion: companion,
                bridgeController: bridgeController,
                onSendPrompt: { prompt in
                    onSendPrompt(prompt)
                },
                onClose: {
                    isIntimacyDetailPresented = false
                }
            )
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isProfileEditPresented) {
            profileEditSheet
        }
    }

    // MARK: - Card 0: User Profile
    private var userProfileCard: some View {
        Button(action: {
            HapticManager.shared.light()
            editingCallname = companion.customPetName
            isProfileEditPresented = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.65, green: 0.44, blue: 0.94), Color(red: 0.81, green: 0.55, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Text("👤")
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(authService.currentUser?.display_name ?? companion.customPetName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("@\(authService.currentUser?.username ?? "siewilly")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.purple.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.2)))
                    }
                    Text("專屬愛稱：\(companion.customPetName) · 點擊修改 SQLite 伴侶檔案")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.85, green: 0.70, blue: 1.0))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.12, blue: 0.26).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Card 1: Intimacy Card (SQLite Connected)
    private var intimacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text("💖")
                    Text("戀人好感羈絆 (SQLite 直連)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(companion.levelIcon) Lv.\(companion.level) \(companion.levelName)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.62, blue: 0.86))
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.45))
                        .frame(height: 7)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color(red: 0.85, green: 0.40, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(companion.progressToNextLevel)), height: 7)
                }
            }
            .frame(height: 7)

            HStack {
                Text("積分：\(companion.intimacyScore) 分 (距 Lv.4 還差 \(companion.pointsNeededForNextLevel) 分)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Text("心情：\(companion.moodTitle) (×\(String(format: "%.1f", companion.moodMultiplier)))")
                    .font(.system(size: 10))
                    .foregroundColor(Color.pink.opacity(0.9))
            }

            // 3 Sub-tabs Pills to open full Intimacy Detail Hub
            HStack(spacing: 8) {
                subPillButton(label: "📖 記憶日記 (\(companion.diaryEntries.count))") {
                    isIntimacyDetailPresented = true
                }
                subPillButton(label: "💬 真心話 (\(companion.qnaAnswers.count))") {
                    isIntimacyDetailPresented = true
                }
                subPillButton(label: "🗺️ 約會劇場") {
                    isIntimacyDetailPresented = true
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.18, green: 0.11, blue: 0.25).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.pink.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func subPillButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.pink.opacity(0.2))
                        .overlay(Capsule().stroke(Color.pink.opacity(0.4), lineWidth: 0.8))
                )
        }
    }

    // MARK: - Card 2: Jukebox Card (Online Search & 4 Dance Styles)
    private var jukeboxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text("🎵")
                    Text("線上搜歌點唱機 & 旋律熱舞")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(jukebox.isPlaying ? "▶ 熱舞播放中" : "⏸ 已暫停")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(jukebox.isPlaying ? .pink : .white.opacity(0.4))
            }

            // Search Bar
            HStack(spacing: 6) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 11))
                    TextField("輸入歌名/歌手 (全網搜歌)...", text: $musicSearchQuery)
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                        .submitLabel(.search)
                        .onSubmit {
                            handleMusicSearch()
                        }
                    if !musicSearchQuery.isEmpty {
                        Button(action: { musicSearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)

                Button(action: {
                    handleMusicSearch()
                }) {
                    Text(isSearchingMusic ? "搜尋中" : "搜尋")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.pink.opacity(0.8))
                        .cornerRadius(10)
                }
                .disabled(musicSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingMusic)
            }

            // Search Results (if any)
            if !searchResults.isEmpty {
                VStack(spacing: 4) {
                    ForEach(searchResults) { track in
                        Button(action: {
                            HapticManager.shared.medium()
                            jukebox.playOnlineTrack(track)
                            showToast("💃 正在線上串流播放：《\(track.title)》")
                        }) {
                            HStack {
                                Text("🎵 \(track.title) - \(track.artist)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                Spacer()
                                Text("▶ 點播")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.pink)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        }
                    }
                }
            }

            // Currently Playing Bar
            HStack(spacing: 12) {
                // Play/Pause button
                Button(action: {
                    HapticManager.shared.medium()
                    jukebox.togglePlayPause()
                }) {
                    Image(systemName: jukebox.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.pink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(jukebox.displayTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(jukebox.displayArtist)
                        .font(.system(size: 10))
                        .foregroundColor(Color.pink.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                // Dance Style Switcher Button
                Button(action: {
                    HapticManager.shared.medium()
                    jukebox.cycleDanceStyle()
                    showToast("💃 已切換舞步：\(jukebox.currentDanceStyle)")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text(jukebox.currentDanceStyle.components(separatedBy: " ").last ?? "熱舞")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.85, green: 0.70, blue: 1.0))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.25))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))

            // 3 Quick Local Tracks
            HStack(spacing: 6) {
                ForEach(0..<jukebox.tracks.count, id: \.self) { idx in
                    let t = jukebox.tracks[idx]
                    let isCur = !jukebox.currentOnlineTrack.isNotNil && jukebox.currentTrackIndex == idx
                    Button(action: {
                        HapticManager.shared.light()
                        jukebox.currentTrackIndex = idx
                        jukebox.playCurrent()
                    }) {
                        Text(t.title)
                            .font(.system(size: 10, weight: isCur ? .bold : .regular))
                            .foregroundColor(isCur ? .pink : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(isCur ? Color.pink.opacity(0.25) : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.16, green: 0.12, blue: 0.26).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func handleMusicSearch() {
        let q = musicSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearchingMusic = true
        Task {
            let res = await companion.searchMusic(query: q)
            await MainActor.run {
                self.searchResults = res
                self.isSearchingMusic = false
            }
        }
    }

    // MARK: - Card 3: Wardrobe Card
    private var wardrobeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text("👗")
                    Text("角色換裝 · 衣櫥 (雙造型熱切換)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(currentOutfit == "classic" ? "❄️ 經典大衣中" : "🌊 夏日泳裝中")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.purple.opacity(0.9))
            }

            HStack(spacing: 10) {
                // Classic
                Button(action: {
                    HapticManager.shared.medium()
                    currentOutfit = "classic"
                    bridgeController?.switchOutfit("classic")
                    showToast("👗 已換上：4星 經典大衣")
                }) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("❄️ 4星 經典大衣")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(currentOutfit == "classic" ? .white : .white.opacity(0.6))
                            Spacer()
                            if currentOutfit == "classic" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 12))
                            }
                        }
                        Text("冰之精靈 · 溫柔端莊")
                            .font(.system(size: 9))
                            .foregroundColor(currentOutfit == "classic" ? Color.purple.opacity(0.9) : .white.opacity(0.4))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(currentOutfit == "classic" ? Color.purple.opacity(0.3) : Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(currentOutfit == "classic" ? Color.purple : Color.white.opacity(0.1), lineWidth: 1))
                    )
                }

                // Swimsuit
                Button(action: {
                    HapticManager.shared.medium()
                    currentOutfit = "swimsuit"
                    bridgeController?.switchOutfit("swimsuit")
                    showToast("👙 已換上：4星 夏日泳裝")
                }) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("👙 4星 夏日泳裝")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(currentOutfit == "swimsuit" ? .white : .white.opacity(0.6))
                            Spacer()
                            if currentOutfit == "swimsuit" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.pink)
                                    .font(.system(size: 12))
                            }
                        }
                        Text("沁涼夏日 · 靈動活潑")
                            .font(.system(size: 9))
                            .foregroundColor(currentOutfit == "swimsuit" ? Color.pink.opacity(0.9) : .white.opacity(0.4))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(currentOutfit == "swimsuit" ? Color.pink.opacity(0.3) : Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(currentOutfit == "swimsuit" ? Color.pink : Color.white.opacity(0.1), lineWidth: 1))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.16, green: 0.12, blue: 0.26).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Card 4: Briefing Card
    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text("🌦️")
                    Text("聯網智慧簡報 (/api/internet-briefing)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: {
                    HapticManager.shared.light()
                    onSendPrompt("愛蜜莉雅，請為我播報今天的台灣即時天氣與最新動漫科技新聞簡報！")
                    onClose()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 9))
                        Text("語音播報")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.8))
                    .cornerRadius(8)
                }
            }

            // Weather Pill
            HStack(spacing: 6) {
                Text("🌤️ \(companion.weather?.city ?? "台北市") \(companion.weather?.temp.map { "\(Int($0))°C" } ?? "24°C")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.cyan)
                Text("• \(companion.weather?.desc ?? "舒適宜人") • 濕度 \(companion.weather?.humidity ?? 72)%")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }

            // News Headlines
            if !companion.news.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(companion.news.prefix(2)) { n in
                        Text("📰 [\(n.source)] \(n.title)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.28).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Card 5: Utilities (Pomodoro, Reset, History, Immersion)
    private var utilitiesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🪄 桌寵日常伴侶實用工具")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                // 1. New Chat (Reset context)
                Button(action: {
                    HapticManager.shared.medium()
                    onResetChat()
                    showToast("💬 已重置對話上下文，展開全新話題！")
                }) {
                    toolItem(icon: "plus.bubble.fill", title: "開啟全新話題", subtitle: "重置對話上下文", color: .purple)
                }

                // 2. Chat History
                Button(action: {
                    HapticManager.shared.light()
                    onOpenHistory()
                }) {
                    toolItem(icon: "clock.arrow.circlepath", title: "歷史記憶錄", subtitle: "瀏覽過往聊天紀錄", color: .blue)
                }

                // 3. Pomodoro Focus Timer
                Button(action: {
                    HapticManager.shared.medium()
                    pomodoro.toggle()
                    showToast(pomodoro.isRunning ? "🍅 番茄鐘專注開始：愛蜜莉雅安靜陪伴您" : "⏸️ 番茄鐘已暫停")
                }) {
                    toolItem(
                        icon: "timer",
                        title: pomodoro.isRunning ? "專注中 \(pomodoro.formattedTime)" : "25分番茄鐘",
                        subtitle: pomodoro.isRunning ? "點擊暫停專注" : "專注工作學習陪伴",
                        color: pomodoro.isRunning ? .green : .red
                    )
                }

                // 4. Pure Immersion Mode
                Button(action: {
                    HapticManager.shared.rigid()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPureImmersionMode = true
                    }
                    onClose()
                }) {
                    toolItem(icon: "eye.fill", title: "純淨賞玩角色", subtitle: "隱藏UI純粹觀賞", color: .pink)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.16, green: 0.12, blue: 0.26).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func toolItem(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    private func showToast(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if toastMessage == text {
                    toastMessage = nil
                }
            }
        }
    }

    // MARK: - Profile Edit Sheet
    private var profileEditSheet: some View {
        VStack(spacing: 16) {
            Text("👤 伴侶身份與專屬愛稱設定")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("愛蜜莉雅對你的專屬稱呼 (目前：\(companion.customPetName))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))

                TextField("輸入愛稱 (例如：有栖)...", text: $editingCallname)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("取消") {
                    isProfileEditPresented = false
                }
                .foregroundColor(.white.opacity(0.6))

                Button("儲存至 SQLite") {
                    let trimmed = editingCallname.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    companion.customPetName = trimmed
                    Task {
                        await companion.patchState(["customPetName": trimmed])
                        try? await authService.updateProfile(displayName: trimmed, callname: trimmed, newPassword: nil)
                    }
                    isProfileEditPresented = false
                    showToast("🌸 已將專屬愛稱「\(trimmed)」同步至 SQLite！")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding(.bottom, 20)
        }
        .presentationDetents([.fraction(0.35)])
    }
}

private extension Optional {
    var isNotNil: Bool { self != nil }
}
