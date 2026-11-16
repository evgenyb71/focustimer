import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var timer: TimerStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The time and end symbol grow with Dynamic Type, capped so the time stays on one line.
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var endSymbolSize: CGFloat = 56

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.backgroundTop.color, Palette.backgroundBottom.color],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    durationPanel
                    statusPanel
                    Button(timer.primaryButtonTitle) {
                        timer.startOrConfirmBreak()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.buttonFill(timer.endState?.accent ?? Palette.focus))
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!timer.canStart)
                    .accessibilityIdentifier("primaryTimerButton")
                    if timer.canFinish {
                        Button("Done") {
                            timer.done()
                        }
                        .buttonStyle(.bordered)
                        .tint(timer.endState?.accent.color)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("doneButton")
                    }
                    if let hint = timer.alertsHint {
                        Label(hint, systemImage: "bell.slash")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("alertsDeniedHint")
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: Header

    /// At accessibility sizes the buttons move above the title, so the title gets the full width.
    @ViewBuilder
    private var header: some View {
        if isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Spacer()
                    headerButtons
                }
                headerTitle
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 12) {
                headerTitle
                Spacer()
                headerButtons
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Focus / Break Timer")
                .font(.title2.bold())
            Text("Run Focus, confirm, then run Break.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText.color)
        }
    }

    private var headerButtons: some View {
        HStack(spacing: 12) {
            if timer.canPause {
                Button {
                    timer.pauseOrResume()
                } label: {
                    Image(systemName: timer.state.paused ? "play.fill" : "pause.fill")
                }
                .accessibilityLabel(timer.state.paused ? "Resume timer" : "Pause timer")
            }
            if timer.canCancel {
                Button {
                    timer.cancel()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Cancel and reset")
            }
        }
        .buttonStyle(.bordered)
        .tint(Palette.focus.color)
    }

    // MARK: Durations

    private var durationPanel: some View {
        VStack(spacing: 16) {
            durationRow(
                title: "Focus Timer",
                seconds: $timer.configuration.durationASeconds,
                range: TimerStore.Configuration.focusRange,
                kind: .focus
            )
            Divider()
            durationRow(
                title: "Break Timer",
                seconds: $timer.configuration.durationBSeconds,
                range: TimerStore.Configuration.breakRange,
                kind: .breakTime
            )
        }
        .padding()
        // Quieter while Focus waits for Break confirmation, so the next action stands out. Only the card fades;
        // the labels and durations stay at full contrast, and the steppers are dimmed as disabled controls.
        .background(Palette.card.color.opacity(durationCardOpacity), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Palette.cardBorder.color.opacity(durationCardOpacity))
        }
    }

    private var durationCardOpacity: Double {
        timer.endState == .focusComplete ? Palette.waitingCardOpacity : 1
    }

    private func durationRow(
        title: String,
        seconds: Binding<Int>,
        range: ClosedRange<Int>,
        kind: TimerStore.ActiveTimer.Kind
    ) -> some View {
        let active = timer.activeTimer?.kind == kind ? timer.activeTimer : nil
        let label = VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(active.map { $0.kind.accent.color } ?? Palette.secondaryText.color)
            Text("\(seconds.wrappedValue / 60) min")
                .font(.headline)
        }
        let stepper = Stepper(value: seconds, in: range, step: 60) { label }
            .disabled(!timer.canEditDurations)
            .accessibilityLabel(title)
            .accessibilityValue(TimerStore.durationAccessibilityValue(seconds: seconds.wrappedValue, active: active != nil))

        return Group {
            // At accessibility sizes the stepper sits under its label instead of beside it.
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    label.accessibilityHidden(true)
                    stepper.labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                stepper
            }
        }
        // The active row is tinted with a bar at its leading edge, lighter while paused.
        .padding(.vertical, 6)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .background {
            if let active {
                RoundedRectangle(cornerRadius: 10)
                    .fill(active.kind.accent.color.opacity(active.paused ? 0.06 : 0.12))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(active.kind.accent.color.opacity(active.paused ? 0.45 : 1))
                            .frame(width: 4)
                            .padding(.vertical, 6)
                    }
            }
        }
    }

    // MARK: Status card

    private var statusPanel: some View {
        VStack(spacing: 10) {
            if let endState = timer.endState, let headline = timer.endHeadline {
                Image(systemName: endState.symbolName)
                    .font(.system(size: min(endSymbolSize, 112)))
                    .foregroundStyle(endState.accent.color)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text(headline)
                        .font(.title.bold())
                    statusMessageText
                }
                .accessibilityElement(children: .combine)
            } else if let active = timer.activeTimer {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: active.paused ? "pause.circle.fill" : active.kind.symbolName)
                            .font(.title2)
                        Text(active.name)
                            .font(.title.bold())
                    }
                    .foregroundStyle(active.kind.accent.color)
                    Text(timer.statusTitle.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText.color)
                    timeText
                        .foregroundStyle(active.paused ? Palette.secondaryText.color : active.kind.accent.color)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(timer.activeTimerAccessibilityLabel ?? active.name)
                .accessibilityIdentifier("activeTimerStatus")
                statusMessageText
            } else {
                VStack(spacing: 10) {
                    Text(timer.statusTitle.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText.color)
                    timeText
                        .accessibilityLabel(timer.statusTimeAccessibilityLabel)
                    statusMessageText
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card.color)
                .overlay {
                    if let accent = timer.endState?.accent {
                        RoundedRectangle(cornerRadius: 16).fill(accent.color.opacity(Palette.endTint))
                    } else if let active = timer.activeTimer {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(active.kind.accent.color.opacity(active.paused ? Palette.pausedTint : Palette.runningTint))
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: cardBorderWidth)
        }
    }

    private var timeText: some View {
        Text(formattedTime)
            .font(.system(size: min(timeSize, 96), weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
    }

    private var cardBorderColor: Color {
        if let accent = timer.endState?.accent { return accent.color.opacity(0.5) }
        if let active = timer.activeTimer { return active.kind.accent.color.opacity(active.paused ? 0.35 : 0.6) }
        return Palette.cardBorder.color
    }

    /// 2 at either end and while a timer runs; 1 while paused and in idle.
    private var cardBorderWidth: CGFloat {
        if timer.endState != nil { return 2 }
        if let active = timer.activeTimer { return active.paused ? 1 : 2 }
        return 1
    }

    private var statusMessageText: some View {
        Text(timer.statusMessage)
            .font(.subheadline)
            .foregroundStyle(Palette.message.color)
            .multilineTextAlignment(.center)
            .frame(minHeight: 20)
    }

    private var formattedTime: String {
        guard let total = timer.displayedSeconds else { return "--:--" }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private extension TimerStore.EndState {
    var symbolName: String {
        switch self {
        case .focusComplete: "cup.and.saucer.fill"
        case .breakComplete: "checkmark.circle.fill"
        }
    }

    /// Amber for Focus end, green for Break end (see `Palette`).
    var accent: Palette.Pair {
        switch self {
        case .focusComplete: Palette.focusComplete
        case .breakComplete: Palette.breakComplete
        }
    }
}

private extension TimerStore.ActiveTimer.Kind {
    var symbolName: String {
        switch self {
        case .focus: "brain.head.profile"
        case .breakTime: "leaf.fill"
        }
    }

    /// Teal for Focus, sage for Break (see `Palette`).
    var accent: Palette.Pair {
        switch self {
        case .focus: Palette.focus
        case .breakTime: Palette.breakTime
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerStore.shared)
}
