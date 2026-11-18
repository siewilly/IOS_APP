import Foundation
import Combine

public final class IntimacyManager: ObservableObject {
    public static let shared = IntimacyManager()

    private enum Keys {
        static let level = "emilia_intimacy_level"
        static let progress = "emilia_intimacy_progress"
        static let interactionCount = "emilia_interaction_count"
    }

    @Published public var level: Int {
        didSet { UserDefaults.standard.set(level, forKey: Keys.level) }
    }

    @Published public var progress: Double {
        didSet { UserDefaults.standard.set(progress, forKey: Keys.progress) }
    }

    @Published public var interactionCount: Int {
        didSet { UserDefaults.standard.set(interactionCount, forKey: Keys.interactionCount) }
    }

    public var levelTitle: String {
        switch level {
        case 1: return "初見相遇"
        case 2: return "微風好感"
        case 3: return "溫柔信賴"
        case 4: return "深情依偎"
        case 5: return "伴侶心動"
        case 6: return "靈魂共鳴"
        case 7: return "契約守護"
        case 8: return "心心相印"
        case 9: return "永恆深愛"
        default: return "至死不渝"
        }
    }

    public var unlockedPerk: String {
        switch level {
        case 1: return "解鎖：基礎碰觸反應"
        case 2: return "解鎖：摸頭微笑"
        case 3: return "解鎖：戳臉縮頸害羞"
        case 4: return "解鎖：摸下巴開懷笑"
        case 5: return "解鎖：契約水晶共鳴"
        case 6: return "解鎖：牽手微語"
        default: return "解鎖：全專屬甜蜜耳語"
        }
    }

    private init() {
        let savedLevel = UserDefaults.standard.integer(forKey: Keys.level)
        let savedProgress = UserDefaults.standard.double(forKey: Keys.progress)
        let savedCount = UserDefaults.standard.integer(forKey: Keys.interactionCount)

        self.level = savedLevel > 0 ? savedLevel : 5
        self.progress = savedProgress > 0 ? savedProgress : 0.86
        self.interactionCount = savedCount > 0 ? savedCount : 42
    }

    public func recordInteraction(points: Double = 0.02) {
        interactionCount += 1
        progress += points
        if progress >= 1.0 {
            if level < 10 {
                level += 1
                progress -= 1.0
            } else {
                progress = 1.0
            }
        }
    }
}
