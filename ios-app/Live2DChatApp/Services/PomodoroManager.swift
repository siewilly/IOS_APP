import Foundation
import Combine

@MainActor
public final class PomodoroManager: ObservableObject {
    public static let shared = PomodoroManager()

    @Published public var isRunning: Bool = false
    @Published public var timeRemaining: Int = 25 * 60 // 25 minutes
    @Published public var completedSessions: Int = 0

    private var timer: Timer?

    public var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var progress: Double {
        let total = 25.0 * 60.0
        return 1.0 - (Double(timeRemaining) / total)
    }

    private init() {}

    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    public func start() {
        isRunning = true
        HapticManager.shared.medium()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.finishSession()
                }
            }
        }
    }

    public func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        HapticManager.shared.light()
    }

    public func reset() {
        pause()
        timeRemaining = 25 * 60
        HapticManager.shared.light()
    }

    private func finishSession() {
        pause()
        completedSessions += 1
        timeRemaining = 25 * 60
        HapticManager.shared.success()
        CompanionSyncService.shared.recordInteraction(points: 20)
    }
}
