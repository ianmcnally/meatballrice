import SwiftUI

@main
struct MeatballriceApp: App {
    @StateObject private var timerManager = TimerManager()

    var body: some Scene {
        MenuBarExtra {
            TimerView(timerManager: timerManager)
        } label: {
            switch timerManager.state {
            case .idle:
                Image(systemName: "timer")
            case .running, .paused:
                Text(timerManager.formattedTime)
                    .monospacedDigit()
            case .completed:
                Image(systemName: "checkmark.circle.fill")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
