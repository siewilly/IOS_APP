import SwiftUI

public struct IntimacyHubDetailSheet: View {
    @ObservedObject var companion: CompanionSyncService
    var bridgeController: Live2DBridgeController?
    var onSendPrompt: ((String) -> Void)?
    var onClose: () -> Void

    @State private var selectedTab: Int = 0
    @State private var answeringQuestion: (id: String, text: String)? = nil
    @State private var answerInput: String = ""
    @State private var toastMessage: String? = nil
    @State private var isGeneratingDiary: Bool = false

    public init(companion: CompanionSyncService, bridgeController: Live2DBridgeController? = nil, onSendPrompt: ((String) -> Void)? = nil, onClose: @escaping () -> Void) {
        self.companion = companion
        self.bridgeController = bridgeController
        self.onSendPrompt = onSendPrompt
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Dark elegant atmospheric background
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.22),
                    Color(red: 0.08, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Text("💖")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("戀人好感羈絆與真實檔案")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("直連 SQLite 資料庫 · 即時雙向同步")
                                .font(.system(size: 10))
                                .foregroundColor(Color.pink.opacity(0.8))
                        }
                    }

                    Spacer()

                    Button(action: {
                        HapticManager.shared.light()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // 4 Segmented Navigation Tabs
                HStack(spacing: 6) {
                    tabButton(index: 0, title: "總覽特權", icon: "sparkles")
                    tabButton(index: 1, title: "記憶日記 (\(companion.diaryEntries.count))", icon: "book.fill")
                    tabButton(index: 2, title: "真心話 (\(companion.qnaAnswers.count))", icon: "heart.text.square.fill")
                    tabButton(index: 3, title: "約會劇場", icon: "map.fill")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.12))

                // Tab Content Area
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0:
                            overviewSection
                        case 1:
                            diarySection
                        case 2:
                            qnaSection
                        default:
                            datesSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }

            // Toast Alert
            if let toast = toastMessage {
                VStack {
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.pink.opacity(0.9)))
                        .shadow(radius: 6)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: Binding(
            get: { answeringQuestion.map { IdentifiableQna(id: $0.id, text: $0.text) } },
            set: { answeringQuestion = $0.map { (id: $0.id, text: $0.text) } }
        )) { item in
            answerQuestionSheet(item: item)
        }
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        Button(action: {
            HapticManager.shared.light()
            selectedTab = index
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(selectedTab == index ? .white : Color.white.opacity(0.6))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedTab == index ? Color.pink.opacity(0.85) : Color.white.opacity(0.06))
            )
        }
    }

    // MARK: - Tab 0: Overview Section
    private var overviewSection: some View {
        VStack(spacing: 14) {
            // Main Level Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(companion.levelIcon) Lv.\(companion.level) \(companion.levelName)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("稱呼：\(companion.customPetName) • 心情：\(companion.moodTitle)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.pink.opacity(0.9))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(companion.intimacyScore) 分")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.pink)
                        Text("加成 ×\(String(format: "%.1f", companion.moodMultiplier))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                            .frame(height: 8)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(companion.progressToNextLevel)), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("本級進度 \(Int(companion.progressToNextLevel * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    if let next = companion.nextTier {
                        Text("距 \(next.name) 還差 \(companion.pointsNeededForNextLevel) 分")
                            .font(.system(size: 11))
                            .foregroundColor(Color.pink.opacity(0.9))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.14, blue: 0.32).opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.pink.opacity(0.35), lineWidth: 1))
            )

            // 8 Tiers List
            VStack(alignment: .leading, spacing: 10) {
                Text("🌸 8 階純愛羈絆進階特權體系")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                ForEach(CompanionSyncService.tiers, id: \.level) { tier in
                    let isUnlocked = companion.intimacyScore >= tier.min
                    HStack(alignment: .top, spacing: 12) {
                        Text(tier.icon)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isUnlocked ? Color.pink.opacity(0.2) : Color.white.opacity(0.05)))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Lv.\(tier.level) \(tier.name)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                                Spacer()
                                Text("\(tier.min) 分")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isUnlocked ? .pink : .white.opacity(0.3))
                            }
                            Text(tier.desc)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(isUnlocked ? 0.7 : 0.3))

                            HStack(spacing: 6) {
                                ForEach(tier.unlocks, id: \.self) { perk in
                                    Text(perk)
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.white.opacity(isUnlocked ? 0.08 : 0.03)))
                                        .foregroundColor(isUnlocked ? Color.pink.opacity(0.85) : .white.opacity(0.25))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isUnlocked ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                    )
                }
            }
        }
    }

    // MARK: - Tab 1: Diary Section
    private var diarySection: some View {
        VStack(spacing: 12) {
            // Generate button
            Button(action: {
                HapticManager.shared.medium()
                isGeneratingDiary = true
                Task {
                    await companion.generateTodayDiary()
                    isGeneratingDiary = false
                    showToast("✨ AI 記憶日記已生成並存入 SQLite！")
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(isGeneratingDiary ? "正在記錄今天的心動回憶..." : "✨ 一鍵生成今日 AI 記憶日記")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
            .disabled(isGeneratingDiary)

            if companion.diaryEntries.isEmpty {
                Text("尚無日記記錄，快點擊上方生成第一篇記憶吧！")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 20)
            } else {
                ForEach(companion.diaryEntries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(entry.levelIcon) \(entry.levelName)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.pink)
                            Spacer()
                            Text("\(entry.date) \(entry.weekday)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Text(entry.content)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(3)
                        HStack {
                            Text("心情：\(entry.mood)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("好感：\(entry.score) 分")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.pink.opacity(0.9))
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.18, green: 0.13, blue: 0.28).opacity(0.85))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                }
            }
        }
    }

    // MARK: - Tab 2: Q&A Section
    private var qnaSection: some View {
        VStack(spacing: 12) {
            Text("💬 戀人真心話深層檔案 (直連 SQLite，共 \(companion.qnaAnswers.count) 題)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.pink.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(companion.qnaAnswers) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.question)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Text(item.date)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Text("「\(item.answer)」")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.70, blue: 0.85))

                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.shared.light()
                            answeringQuestion = (id: item.id, text: item.question)
                            answerInput = item.answer
                        }) {
                            Text("✏️ 修改回答")
                                .font(.system(size: 10))
                                .foregroundColor(.pink)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.18, green: 0.13, blue: 0.28).opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pink.opacity(0.2), lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Tab 3: Dates Section
    private var datesSection: some View {
        VStack(spacing: 14) {
            dateCard(
                title: "王都紫羅蘭花海野餐",
                icon: "🌸",
                desc: "微風輕輕吹過滿山谷的紫羅蘭花海，愛蜜莉雅鋪好亞麻野餐墊，回過頭朝你露出比花朵還燦爛的微笑：「能像這樣只有我們兩個人出來散心，真的好幸福喔～」",
                options: [
                    ("幫她撥開臉頰邊隨風飄散的銀髮", "🌸 愛蜜莉雅臉頰瞬間染紅，輕輕握住你的手指：「哇…太近了啦，心跳都漏掉一拍了…」", "exp_06_blushing_heavy"),
                    ("親手餵她吃一小塊現烤蘋菓派", "🍎 愛蜜莉雅眼睛亮晶晶地咬下一口：「好甜！…嗯，因為是你餵的才這麼好吃喔！」", "exp_02_happy_big"),
                    ("牽起她的手仰望藍天", "💖 愛蜜莉雅十指緊扣著你的手，靠在你的肩側微笑：「只要有你在身邊，哪裡都是最棒的地方。」", "exp_21_adoration_sparkle")
                ]
            )

            dateCard(
                title: "南國陽光海灘戲水",
                icon: "🏖️",
                desc: "耀眼的夏日海風與浪花聲伴隨在耳畔！愛蜜莉雅換上清涼的夏日泳裝，略帶害羞地整理著裙擺：「那個……只給你看的話沒關係喔！」",
                options: [
                    ("稱讚夏日泳裝超級可愛又迷人", "🏖️ 愛蜜莉雅雙手捧著發燙的臉頰：「唔哇！你直接這樣講出來也太犯規了啦！」", "exp_06_blushing_heavy"),
                    ("買來兩杯冰涼的水果特調乾杯", "🍹 愛蜜莉雅開心地輕啜一口：「冰冰涼涼的好消暑！來，這口草莓也分你吃！」", "exp_03_wink"),
                    ("並肩赤腳踩在浪花裡慢慢散步", "🌊 愛蜜莉雅俏皮地挽住你的手臂：「不許偷偷放開喔，走散了怎麼辦嘛～」", "exp_01_smile")
                ]
            )

            dateCard(
                title: "露格尼卡觀星塔夜談",
                icon: "🌌",
                desc: "滿天星辰宛如銀粉般傾瀉而下，紫紺色的眼眸倒映著銀河：「今天晚上，整個世界的星星好像都在為我們閃爍呢。」",
                options: [
                    ("脫下外套披在她的肩膀上保暖", "🌌 愛蜜莉雅微紅著臉靠過來：「好溫暖…可以再靠你近一點點嗎？」", "exp_05_shy"),
                    ("指著流星許下永遠在一起的願望", "🌠 愛蜜莉雅雙手合十微笑：「我也許了一模一樣的願望喔！」", "exp_21_adoration_sparkle"),
                    ("在額頭上落下一記輕柔晚安吻", "💫 愛蜜莉雅呆住兩秒後臉紅到耳根：「唔…！這個驚喜太過分了啦…💕」", "exp_06_blushing_heavy")
                ]
            )
        }
    }

    private func dateCard(title: String, icon: String, desc: String, options: [(label: String, reaction: String, exp: String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(icon)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(desc)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(2)

            VStack(spacing: 6) {
                ForEach(options, id: \.label) { opt in
                    Button(action: {
                        HapticManager.shared.medium()
                        bridgeController?.setExpression(opt.exp)
                        bridgeController?.triggerMotion(group: "Happy")
                        companion.recordInteraction(points: 15)
                        showToast(opt.reaction)
                        onSendPrompt?("【\(title)】\(opt.label)")
                    }) {
                        HStack {
                            Text("💬 \(opt.label)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.pink)
                            Spacer()
                            Text("+15 好感")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.pink.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.pink.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pink.opacity(0.3), lineWidth: 1))
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.18, green: 0.13, blue: 0.28).opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
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

    private func answerQuestionSheet(item: IdentifiableQna) -> some View {
        VStack(spacing: 16) {
            Text("💬 戀人真心話回答")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text(item.text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            TextField("輸入你的回答...", text: $answerInput)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("取消") {
                    answeringQuestion = nil
                }
                .foregroundColor(.white.opacity(0.6))

                Button("儲存至 SQLite") {
                    let trimmed = answerInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    companion.saveQnaAnswer(questionId: item.id, question: item.text, answer: trimmed)
                    answeringQuestion = nil
                    showToast("🌸 已將真心話儲存至 SQLite！好感度 +10！")
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(answerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.bottom, 20)
        }
        .presentationDetents([.fraction(0.4)])
    }
}

private struct IdentifiableQna: Identifiable {
    let id: String
    let text: String
}
