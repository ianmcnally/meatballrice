import Foundation
import UserNotifications
import AppKit

extension Notification.Name {
    static let nudgeTapped = Notification.Name("nudgeTapped")
}

enum TimerState {
    case idle
    case running
    case paused
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier.hasPrefix("nudge-") {
            NotificationCenter.default.post(name: .nudgeTapped, object: nil)
        }
        completionHandler()
    }
}

@MainActor
class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var selectedDuration: TimeInterval = 25 * 60
    @Published var lastTimerCompletedAt: Date?

    private var timer: Timer?
    private var endDate: Date?
    private let notificationDelegate = NotificationDelegate()
    private var screenWakeObserver: NSObjectProtocol?
    private var lastNudgeSentAt: Date?

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
        lastTimerCompletedAt = Date()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        registerScreenWakeObserver()
        NotificationCenter.default.addObserver(
            forName: .nudgeTapped, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .idle else { return }
                self.start()
            }
        }
    }

    deinit {
        if let screenWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(screenWakeObserver)
        }
    }

    private func registerScreenWakeObserver() {
        screenWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay so macOS has time to fully wake the display —
            // notifications sent immediately on wake get silently
            // routed to Notification Center without a banner.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Task { @MainActor in
                    self?.handleScreenWake()
                }
            }
        }
    }

    private func handleScreenWake() {
        let nudgeEnabled = UserDefaults.standard.object(forKey: "nudgeEnabled") as? Bool ?? true
        guard nudgeEnabled else { return }
        guard state == .idle else { return }

        let nudgeIdleMinutes = UserDefaults.standard.object(forKey: "nudgeIdleMinutes") as? Int ?? 10
        let idleGap = TimeInterval(nudgeIdleMinutes * 60)

        if let lastCompleted = lastTimerCompletedAt,
           Date().timeIntervalSince(lastCompleted) >= idleGap {
            // Prevent duplicate nudges within 5 minutes
            if let lastNudge = lastNudgeSentAt,
               Date().timeIntervalSince(lastNudge) < 300 {
                return
            }
            sendNudgeNotification()
            lastNudgeSentAt = Date()
        }
    }

    private func sendNudgeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "meatballrice"
        content.body = "Start a focus timer?"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "nudge-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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

    func setDurationSeconds(_ seconds: TimeInterval) {
        guard state == .idle else { return }
        selectedDuration = seconds
        timeRemaining = seconds
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
        timer?.invalidate()
        timer = nil
        lastTimerCompletedAt = Date()
        playSound()
        sendNotification()
        stop()
    }

    private func playSound() {
        NSSound(named: "Glass")?.play()
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
