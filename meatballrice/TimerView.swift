import SwiftUI

struct TimerView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var sliderMinutes: Double = 25
    @State private var isHoveringQuit = false
    @State private var isEditing = false
    @State private var editText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Timer display — tap to edit when idle
            if isEditing {
                TextField("", text: $editText)
                    .font(.system(size: 52, weight: .thin, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .frame(width: 160)
                    .onSubmit { commitEdit() }
                    .onExitCommand { cancelEdit() }
            } else {
                Text(timerManager.formattedTime)
                    .font(.system(size: 52, weight: .thin, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: timerManager.formattedTime)
                    .onTapGesture {
                        guard timerManager.state == .idle else { return }
                        editText = "\(Int(sliderMinutes))"
                        isEditing = true
                        isTextFieldFocused = true
                    }
            }

            Spacer().frame(height: 20)

            // Content area with fixed height to prevent layout jumps
            VStack(spacing: 14) {
                switch timerManager.state {
                case .idle:
                    idleControls
                case .running:
                    runningControls
                case .paused:
                    pausedControls
                }
            }
            .frame(height: 120)

            // Quit
            Text("Quit")
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(isHoveringQuit ? 0.4 : 0.2))
                .onHover { isHoveringQuit = $0 }
                .onTapGesture { NSApplication.shared.terminate(nil) }
                .padding(.bottom, 14)
        }
        .frame(width: 220)
        .onAppear {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 36 && timerManager.state == .idle && !isEditing {
                    timerManager.start()
                    dismissPopover()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            keyMonitor = nil
        }
    }

    private func commitEdit() {
        let text = editText.trimmingCharacters(in: .whitespaces)
        if text.contains(":") {
            // Parse mm:ss or :ss format
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count == 2 {
                let mins = Double(parts[0]) ?? 0
                let secs = Double(parts[1]) ?? 0
                if mins >= 0, mins <= 120, secs >= 0, secs < 60 {
                    let totalSeconds = mins * 60 + secs
                    if totalSeconds >= 1 && totalSeconds <= 120 * 60 {
                        timerManager.setDurationSeconds(totalSeconds)
                    }
                }
            }
        } else if let mins = Double(text), mins >= 1, mins <= 120 {
            sliderMinutes = round(mins)
            timerManager.setDuration(sliderMinutes)
        }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
    }

    private func dismissPopover() {
        NSApp.keyWindow?.close()
    }

    // MARK: - Idle

    private var idleControls: some View {
        VStack(spacing: 14) {
            // Custom thin slider
            CustomSlider(value: $sliderMinutes, range: 1...120)
                .frame(height: 20)
                .padding(.horizontal, 24)
                .onChange(of: sliderMinutes) {
                    timerManager.setDuration(sliderMinutes)
                }

            // Presets as minimal text
            HStack(spacing: 0) {
                ForEach(Array(Preset.defaults.enumerated()), id: \.element.id) { index, preset in
                    if index > 0 {
                        Text("·")
                            .foregroundStyle(.primary.opacity(0.2))
                            .font(.system(size: 10))
                    }
                    PresetButton(
                        title: "\(preset.minutes)m",
                        isSelected: Int(sliderMinutes) == preset.minutes
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sliderMinutes = Double(preset.minutes)
                            timerManager.selectPreset(preset)
                        }
                    }
                }
            }

            // Start — subtle, not a big blue pill
            StartButton {
                timerManager.start()
                dismissPopover()
            }
        }
    }

    // MARK: - Running

    private var runningControls: some View {
        VStack(spacing: 16) {
            // Thin progress bar
            ProgressBar(progress: timerManager.progress, color: .accentColor)
                .padding(.horizontal, 24)

            HStack(spacing: 24) {
                IconButton(systemName: "pause.fill", size: 13) {
                    timerManager.pause()
                }
                IconButton(systemName: "stop.fill", size: 12) {
                    timerManager.stop()
                    sliderMinutes = timerManager.selectedDuration / 60
                }
            }
        }
    }

    // MARK: - Paused

    private var pausedControls: some View {
        VStack(spacing: 16) {
            ProgressBar(progress: timerManager.progress, color: .secondary)
                .padding(.horizontal, 24)

            HStack(spacing: 24) {
                IconButton(systemName: "play.fill", size: 13, tinted: true) {
                    timerManager.resume()
                }
                IconButton(systemName: "stop.fill", size: 12) {
                    timerManager.stop()
                    sliderMinutes = timerManager.selectedDuration / 60
                }
            }
        }
    }

}

// MARK: - Custom Slider

private struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var isHovering = false
    @State private var isDragging = false

    private var fraction: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let thumbX = trackWidth * fraction

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(height: 4)

                // Track fill
                Capsule()
                    .fill(.primary)
                    .frame(width: thumbX, height: 4)

                // Thumb
                Circle()
                    .fill(.primary)
                    .frame(width: 12, height: 12)
                    .offset(x: thumbX - 5)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let fraction = min(max(drag.location.x / trackWidth, 0), 1)
                        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                        value = round(raw)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { isHovering = $0 }
        }
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.06))
                    .frame(height: 2)
                Capsule()
                    .fill(color.opacity(0.5))
                    .frame(width: max(0, geo.size.width * progress), height: 2)
                    .animation(.linear(duration: 0.5), value: progress)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
            .foregroundStyle(.primary.opacity(isSelected ? 0.8 : (isHovering ? 0.5 : 0.35)))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onHover { isHovering = $0 }
    }
}

// MARK: - Start Button

private struct StartButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Text("Start")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary.opacity(isHovering ? 0.9 : 0.7))
            .padding(.horizontal, 24)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.primary.opacity(isHovering ? 0.12 : 0.08))
            )
            .contentShape(Capsule())
            .onTapGesture(perform: action)
            .onHover { isHovering = $0 }
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let systemName: String
    var size: CGFloat = 14
    var tinted: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(
                tinted
                    ? Color.primary.opacity(isHovering ? 0.8 : 0.6)
                    : Color.primary.opacity(isHovering ? 0.5 : 0.3)
            )
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .onHover { isHovering = $0 }
    }
}
