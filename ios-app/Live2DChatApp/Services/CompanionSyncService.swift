import Foundation
import Combine

public struct DiaryEntry: Codable, Identifiable {
    public let id: Int64
    public let date: String
    public let weekday: String
    public let levelName: String
    public let levelIcon: String
    public let score: Int
    public let content: String
    public let mood: String

    public init(id: Int64, date: String, weekday: String, levelName: String, levelIcon: String, score: Int, content: String, mood: String) {
        self.id = id
        self.date = date
        self.weekday = weekday
        self.levelName = levelName
        self.levelIcon = levelIcon
        self.score = score
        self.content = content
        self.mood = mood
    }
}

public struct QnaAnswer: Codable, Identifiable {
    public let id: String
    public let question: String
    public let answer: String
    public let date: String

    public init(id: String, question: String, answer: String, date: String) {
        self.id = id
        self.question = question
        self.answer = answer
        self.date = date
    }
}

public struct DateMemory: Codable, Identifiable {
    public let id: String
    public let title: String
    public let date: String
    public let choiceLabel: String
    public let icon: String

    public init(id: String, title: String, date: String, choiceLabel: String, icon: String) {
        self.id = id
        self.title = title
        self.date = date
        self.choiceLabel = choiceLabel
        self.icon = icon
    }
}

public struct OnlineMusicTrack: Codable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let cover: String?
    public let duration: Double?
    public let stream_url: String?

    public init(id: String, title: String, artist: String, album: String? = nil, cover: String? = nil, duration: Double? = nil, stream_url: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.cover = cover
        self.duration = duration
        self.stream_url = stream_url
    }
}

public struct BriefingWeather: Codable {
    public let city: String?
    public let temp: Double?
    public let desc: String?
    public let humidity: Int?
    public let apparent_temp: Double?
    public let ok: Bool?
}

public struct BriefingNews: Codable, Identifiable {
    public var id: String { title }
    public let title: String
    public let source: String
    public let link: String?
}

public struct LevelTier {
    public let level: Int
    public let name: String
    public let min: Int
    public let icon: String
    public let colorHex: String
    public let desc: String
    public let unlocks: [String]
}

public final class CompanionSyncService: ObservableObject {
    public static let shared = CompanionSyncService()

    public static let tiers: [LevelTier] = [
        LevelTier(level: 1, name: "初識同伴", min: 0, icon: "🌱", colorHex: "#ba9cff", desc: "客氣端莊、矜持禮貌，視你為值得信任的同行者。", unlocks: ["基礎日常對話", "撫摸銀髮 (頭部)", "戳戳臉頰 (基礎)", "番茄鐘專注陪伴"]),
        LevelTier(level: 2, name: "信任夥伴", min: 80, icon: "🌿", colorHex: "#a8ffcb", desc: "放下戒心，展現天然呆與少女心性，偶爾可愛抱怨。", unlocks: ["🌿 拉衣角 / 輕拍肩", "半瞇眼臉紅微表情", "偶爾天然呆生活碎碎念"]),
        LevelTier(level: 3, name: "知心守護", min: 220, icon: "🌸", colorHex: "#ffd285", desc: "極度在乎你的起居與情緒，心靈深處最信任的知己。", unlocks: ["🌸 雙手輕捧臉頰", "🥹 破涕為笑安撫暴擊機制", "📖 AI 真實記憶日記"]),
        LevelTier(level: 4, name: "專屬戀人 (EMT)", min: 450, icon: "💖", colorHex: "#ff9edb", desc: "甜蜜依賴、深情眷戀，屬於你們兩人的純愛戀愛起點！", unlocks: ["🏷️ 專屬愛稱呼喚設定", "🤝 十指緊扣牽手", "😳 輕捏臉頰破功", "🗺️ 戀人約會小劇場", "💌 戀人親筆情書"]),
        LevelTier(level: 5, name: "精靈的契約者", min: 800, icon: "💍", colorHex: "#ff85c8", desc: "視你為唯一的靈魂伴侶，會主動撒嬌討拍與分享心事。", unlocks: ["🍎 親手甜蜜餵食點心", "💎 契約水晶心跳共鳴", "🗺️ 全主題約會劇場解鎖", "📸 約會紀念卡典藏"]),
        LevelTier(level: 6, name: "月下花海的誓約", min: 1300, icon: "🌙", colorHex: "#c8b6ff", desc: "夜晚展現溫柔微醺與耳語般的深情依戀。", unlocks: ["🌙 背後環抱 / 靠肩依偎", "🌙 耳畔早安/晚安親密問候", "❓ 戀人真心話深層檔案"]),
        LevelTier(level: 7, name: "銀白之戀 · 冰結羈絆", min: 2000, icon: "❄️", colorHex: "#9be7ff", desc: "心意相通，自然回憶並守護專屬於兩人的點點滴滴。", unlocks: ["❄️ 摸摸下巴逗她開懷笑", "❄️ 純愛回憶深度語音連動", "💞 吃醋秒變害羞黏人"]),
        LevelTier(level: 8, name: "永恆的半身 (MAX+)", min: 2800, icon: "👑", colorHex: "#ffe57f", desc: "永恆不渝的純愛伴侶，每累積 +350 分即點亮一顆星 ★！", unlocks: ["👑 主動向螢幕索抱 / 索吻", "👑 無限星級輝煌進階 (+350/★)", "💐 永恆純愛誓約"])
    ]

    @Published public var intimacyScore: Int = 271
    @Published public var moodScore: Int = 100
    @Published public var moodState: String = "exuberant"
    @Published public var padVector: [String: Double] = ["p": 1.0, "a": 0.33, "d": 0.04]
    @Published public var customPetName: String = "有栖"
    @Published public var isJealous: Bool = false
    @Published public var coaxProgress: Int = 0
    @Published public var currentModel: String = "emilia_4star"
    @Published public var diaryEntries: [DiaryEntry] = []
    @Published public var dateMemories: [DateMemory] = []
    @Published public var qnaAnswers: [QnaAnswer] = []

    @Published public var weather: BriefingWeather?
    @Published public var news: [BriefingNews] = []
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date = Date()

    // MARK: - Computed Level Info
    public var currentTier: LevelTier {
        for tier in Self.tiers.reversed() {
            if intimacyScore >= tier.min {
                return tier
            }
        }
        return Self.tiers[0]
    }

    public var nextTier: LevelTier? {
        let cur = currentTier
        if let idx = Self.tiers.firstIndex(where: { $0.level == cur.level }), idx + 1 < Self.tiers.count {
            return Self.tiers[idx + 1]
        }
        return nil
    }

    public var level: Int { currentTier.level }
    public var levelName: String { currentTier.name }
    public var levelIcon: String { currentTier.icon }

    public var progressToNextLevel: Double {
        guard let next = nextTier else { return 1.0 }
        let currentMin = currentTier.min
        let span = next.min - currentMin
        guard span > 0 else { return 1.0 }
        let currentProg = intimacyScore - currentMin
        return max(0.0, min(1.0, Double(currentProg) / Double(span)))
    }

    public var pointsNeededForNextLevel: Int {
        guard let next = nextTier else { return 0 }
        return max(0, next.min - intimacyScore)
    }

    public var moodTitle: String {
        if moodScore >= 90 { return "💖 甜蜜依戀" }
        if moodScore >= 70 { return "🌸 溫馨陪伴" }
        if moodScore >= 50 { return "😊 恬淡平靜" }
        return "🌧️ 稍微有些落寞"
    }

    public var moodMultiplier: Double {
        if moodScore >= 90 { return 1.5 }
        if moodScore >= 70 { return 1.2 }
        if moodScore >= 50 { return 1.0 }
        return 0.8
    }

    private init() {
        // Fallback default sample data if offline
        loadFromLocalStorage()
    }

    private func getBaseURL() -> String {
        return ServerConfigManager.shared.serverBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Synchronize from SQLite Backend
    public func fetchCompanionState() async {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/companion-state") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        await MainActor.run { isSyncing = true }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { isSyncing = false }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? [String: Any] {
                await MainActor.run {
                    self.applyState(state)
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                    self.saveToLocalStorage()
                }
            }
        } catch {
            print("[CompanionSyncService] fetch error:", error)
            await MainActor.run { isSyncing = false }
        }
    }

    // MARK: - Apply State Dictionary
    @MainActor
    private func applyState(_ state: [String: Any]) {
        if let score = state["intimacyScore"] as? Int {
            self.intimacyScore = score
        }
        if let mood = state["moodScore"] as? Int {
            self.moodScore = mood
        }
        if let stateStr = state["moodState"] as? String {
            self.moodState = stateStr
        }
        if let pad = state["padVector"] as? [String: Double] {
            self.padVector = pad
        }
        if let name = state["customPetName"] as? String, !name.isEmpty {
            self.customPetName = name
        }
        if let jealous = state["isJealous"] as? Bool {
            self.isJealous = jealous
        }
        if let model = state["currentModel"] as? String {
            self.currentModel = model
        }

        // Decode Diary Entries
        if let diariesArr = state["diaryEntries"] as? [[String: Any]] {
            self.diaryEntries = diariesArr.compactMap { d in
                guard let id = d["id"] as? Int64 ?? (d["id"] as? NSNumber)?.int64Value,
                      let date = d["date"] as? String,
                      let content = d["content"] as? String else { return nil }
                let weekday = d["weekday"] as? String ?? ""
                let levelName = d["levelName"] as? String ?? "知心守護"
                let levelIcon = d["levelIcon"] as? String ?? "🌸"
                let score = d["score"] as? Int ?? self.intimacyScore
                let mood = d["mood"] as? String ?? "🌸 溫馨陪伴"
                return DiaryEntry(id: id, date: date, weekday: weekday, levelName: levelName, levelIcon: levelIcon, score: score, content: content, mood: mood)
            }
        }

        // Decode Q&A Answers
        if let qnaArr = state["qnaAnswers"] as? [[String: Any]] {
            self.qnaAnswers = qnaArr.compactMap { q in
                guard let id = q["id"] as? String,
                      let question = q["question"] as? String,
                      let answer = q["answer"] as? String else { return nil }
                let date = q["date"] as? String ?? ""
                return QnaAnswer(id: id, question: question, answer: answer, date: date)
            }
        }

        // Decode Date Memories
        if let datesArr = state["dateMemories"] as? [[String: Any]] {
            self.dateMemories = datesArr.compactMap { dm in
                guard let id = dm["id"] as? String,
                      let title = dm["title"] as? String else { return nil }
                let date = dm["date"] as? String ?? ""
                let choiceLabel = dm["choiceLabel"] as? String ?? ""
                let icon = dm["icon"] as? String ?? "🌸"
                return DateMemory(id: id, title: title, date: date, choiceLabel: choiceLabel, icon: icon)
            }
        }
    }

    // MARK: - Patch to SQLite Backend
    public func patchState(_ patch: [String: Any]) async {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/companion-state") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: patch)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? [String: Any] {
                await MainActor.run {
                    self.applyState(state)
                    self.saveToLocalStorage()
                }
            }
        } catch {
            print("[CompanionSyncService] patch error:", error)
        }
    }

    // MARK: - Increase Intimacy Score (e.g. Touch, chat)
    public func recordInteraction(points: Int = 1) {
        let finalPts = Int(Double(points) * moodMultiplier)
        intimacyScore += finalPts
        saveToLocalStorage()
        Task {
            await patchState(["intimacyScore": self.intimacyScore])
        }
    }

    // MARK: - Save QnA Answer
    public func saveQnaAnswer(questionId: String, question: String, answer: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let dateStr = formatter.string(from: Date())

        var list = self.qnaAnswers
        list.removeAll(where: { $0.id == questionId })
        let newEntry = QnaAnswer(id: questionId, question: question, answer: answer, date: dateStr)
        list.insert(newEntry, at: 0)
        self.qnaAnswers = list
        recordInteraction(points: 10)

        // Patch array
        let rawArr: [[String: String]] = list.map {
            ["id": $0.id, "question": $0.question, "answer": $0.answer, "date": $0.date]
        }
        Task {
            await patchState(["qnaAnswers": rawArr])
        }
    }

    // MARK: - Generate Today's AI Diary Entry
    public func generateTodayDiary() async {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/generate-diary") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await fetchCompanionState()
            }
        } catch {
            print("[CompanionSyncService] generateTodayDiary error:", error)
        }
    }

    // MARK: - Fetch Briefing (Weather & News)
    public func fetchBriefing() async {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/internet-briefing?city=Taipei&limit=3") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let weatherDict = json["weather"] as? [String: Any] {
                    let city = weatherDict["city"] as? String ?? "台北"
                    let temp = (weatherDict["temp"] as? NSNumber)?.doubleValue
                    let desc = weatherDict["desc"] as? String ?? ""
                    let humidity = weatherDict["humidity"] as? Int ?? 75
                    let apparent = (weatherDict["apparent_temp"] as? NSNumber)?.doubleValue
                    let ok = weatherDict["ok"] as? Bool ?? true
                    await MainActor.run {
                        self.weather = BriefingWeather(city: city, temp: temp, desc: desc, humidity: humidity, apparent_temp: apparent, ok: ok)
                    }
                }
                if let newsArr = json["news"] as? [[String: Any]] {
                    let items: [BriefingNews] = newsArr.compactMap { n in
                        guard let title = n["title"] as? String else { return nil }
                        let source = n["source"] as? String ?? "巴哈姆特"
                        let link = n["link"] as? String
                        return BriefingNews(title: title, source: source, link: link)
                    }
                    await MainActor.run {
                        self.news = items
                    }
                }
            }
        } catch {
            print("[CompanionSyncService] fetchBriefing error:", error)
        }
    }

    // MARK: - Search Music
    public func searchMusic(query: String) async -> [OnlineMusicTrack] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/music-search?q=\(encoded)") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(for: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tracksArr = json["tracks"] as? [[String: Any]] {
                return tracksArr.compactMap { t in
                    guard let id = t["id"] as? String,
                          let title = t["title"] as? String,
                          let artist = t["artist"] as? String else { return nil }
                    let album = t["album"] as? String
                    let cover = t["cover"] as? String
                    let duration = (t["duration"] as? NSNumber)?.doubleValue
                    let stream = t["stream_url"] as? String
                    return OnlineMusicTrack(id: id, title: title, artist: artist, album: album, cover: cover, duration: duration, stream_url: stream)
                }
            }
        } catch {
            print("[CompanionSyncService] searchMusic error:", error)
        }
        return []
    }

    // MARK: - Local Persistence Fallback
    private func saveToLocalStorage() {
        UserDefaults.standard.set(intimacyScore, forKey: "emilia_intimacy_score")
        UserDefaults.standard.set(moodScore, forKey: "emilia_mood_score")
        UserDefaults.standard.set(customPetName, forKey: "emilia_callname")
    }

    private func loadFromLocalStorage() {
        let savedScore = UserDefaults.standard.integer(forKey: "emilia_intimacy_score")
        if savedScore > 0 {
            self.intimacyScore = savedScore
        }
        let savedMood = UserDefaults.standard.integer(forKey: "emilia_mood_score")
        if savedMood > 0 {
            self.moodScore = savedMood
        }
        if let savedName = UserDefaults.standard.string(forKey: "emilia_callname"), !savedName.isEmpty {
            self.customPetName = savedName
        }
    }
}
