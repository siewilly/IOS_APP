import SwiftUI

public struct EmiliaControlCenterSheet: View {
    @ObservedObject var jukebox: JukeboxManager
    @ObservedObject var intimacy: IntimacyManager
    @ObservedObject var bridgeController: Live2DBridgeController
    @Binding var currentOutfit: String
    @Binding var isPureImmersionMode: Bool
    var onSendPrompt: (String) -> Void
    var onClose: () -> Void

    public init(
        jukebox: JukeboxManager = .shared,
        intimacy: IntimacyManager = .shared,
        bridgeController: Live2DBridgeController,
        currentOutfit: Binding<String>,
        isPureImmersionMode: Binding<Bool>,
        onSendPrompt: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.jukebox = jukebox
        self.intimacy = intimacy
        self.bridgeController = bridgeController
        self._currentOutfit = currentOutfit
        self._isPureImmersionMode = isPureImmersionMode
        self.onSendPrompt = onSendPrompt
        self.onClose = onClose
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.10, green: 0.07, blue: 0.18)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 1. Jukebox & Dance Card
                        jukeboxSection

                        // 2. Wardrobe Outfit Switcher
                        wardrobeSection

                        // 3. Intimacy & Bond Card
                        intimacySection

                        // 4. Quick Utility Tools
                        utilitySection

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("💎 愛蜜莉雅靈動控制台中樞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Jukebox & Dance
    private var jukeboxSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .foregroundColor(Color.pink.opacity(0.9))
                    Text("線上點唱機 & 熱舞編舞")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                if jukebox.isPlaying {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 6, height: 6)
                        Text("正在播放")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.pink)
                    }
                }
            }

            // Track Player Row
            HStack(spacing: 14) {
                // Album Art Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: jukebox.currentTrack.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(jukebox.currentTrack.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(jukebox.currentTrack.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Playback Controls
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.light()
                        jukebox.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Button(action: {
                        HapticManager.shared.medium()
                        jukebox.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 36, height: 36)
                            Image(systemName: jukebox.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Button(action: {
                        HapticManager.shared.light()
                        jukebox.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Dance Style Switcher Row
            HStack {
                Text("舞步風格：")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))

                Text(jukebox.currentDanceStyle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 1.0))

                Spacer()

                Button(action: {
                    HapticManager.shared.selection()
                    jukebox.cycleDanceStyle()
                }) {
                    HStack(spacing: 4) {
                        Text("切換舞步")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color.pink.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.17, green: 0.12, blue: 0.30).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Wardrobe Section
    private var wardrobeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tshirt.fill")
                        .foregroundColor(Color.cyan)
                    Text("一鍵衣櫥換裝")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("無縫熱切換")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 12) {
                // Classic
                Button(action: {
                    HapticManager.shared.medium()
                    currentOutfit = "classic"
                    bridgeController.switchOutfit("classic")
                }) {
                    HStack(spacing: 8) {
                        Text("✨")
                        Text("4星 經典大衣")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(currentOutfit == "classic" ? Color.purple.opacity(0.35) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(currentOutfit == "classic" ? Color.purple : Color.clear, lineWidth: 1.5)
                            )
                    )
                    .foregroundColor(.white)
                }

                // Swimsuit
                Button(action: {
                    HapticManager.shared.medium()
                    currentOutfit = "swimsuit"
                    bridgeController.switchOutfit("swimsuit")
                }) {
                    HStack(spacing: 8) {
                        Text("👙")
                        Text("4星 夏日泳裝")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(currentOutfit == "swimsuit" ? Color.pink.opacity(0.35) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(currentOutfit == "swimsuit" ? Color.pink : Color.clear, lineWidth: 1.5)
                            )
                    )
                    .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.17, green: 0.12, blue: 0.30).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Intimacy Section
    private var intimacySection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color.pink)
                    Text("戀人好感度羈絆")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(intimacy.levelTitle) Lv.\(intimacy.level)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.pink)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(1.0, intimacy.progress)), height: 7)
                }
            }
            .frame(height: 7)

            HStack {
                Text("累計陪伴互動：\(intimacy.interactionCount) 次")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(intimacy.unlockedPerk)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.85, green: 0.70, blue: 1.0))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.17, green: 0.12, blue: 0.30).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Utility Section
    private var utilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("實用小工具")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 10) {
                // Daily Briefing
                Button(action: {
                    HapticManager.shared.medium()
                    onSendPrompt("愛蜜莉雅，請為我播報今天的即時天氣與最新動漫科技簡報！")
                    onClose()
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                        Text("今日晨間簡報")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Chat History
                Button(action: {
                    HapticManager.shared.light()
                    onSendPrompt("愛蜜莉雅，我們今天都聊了些什麼呢？幫我總結一下～")
                    onClose()
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundColor(.cyan)
                        Text("歷史回憶錄")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Pure Immersion Mode
                Button(action: {
                    HapticManager.shared.rigid()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPureImmersionMode = true
                    }
                    onClose()
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.pink)
                        Text("純淨賞玩角色")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.17, green: 0.12, blue: 0.30).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
