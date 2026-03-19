import Foundation
import UserNotifications
import AppKit

enum TimerState {
    case idle
    case running
    case paused
    case completed
}

@MainActor
class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var selectedDuration: TimeInterval = 25 * 60

    private var timer: Timer?
    private var endDate: Date?

    var formattedTime: String {
        let total = max(0, Int(timeRemaining))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard selectedDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / selectedDuration)
    }

    init() {
        requestNotificationPermission()
    }

    func start() {
        state = .running
        endDate = Date().addingTimeInterval(timeRemaining)
        startTimer()
    }

    func pause() {
        state = .paused
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        state = .running
        endDate = Date().addingTimeInterval(timeRemaining)
        startTimer()
    }

    func stop() {
        state = .idle
        timer?.invalidate()
        timer = nil
        timeRemaining = selectedDuration
    }

    func selectPreset(_ preset: Preset) {
        stop()
        selectedDuration = preset.duration
        timeRemaining = preset.duration
    }

    func setDuration(_ minutes: Double) {
        guard state == .idle else { return }
        selectedDuration = minutes * 60
        timeRemaining = minutes * 60
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let endDate else { return }
        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
            timeRemaining = 0
            complete()
        } else {
            timeRemaining = remaining
        }
    }

    private func complete() {
        state = .completed
        timer?.invalidate()
        timer = nil
        playSound()
        sendNotification()
    }

    private func playSound() {
        NSSound(named: "Glass")?.play()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "meatballrice"
        content.body = "Timer complete!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
