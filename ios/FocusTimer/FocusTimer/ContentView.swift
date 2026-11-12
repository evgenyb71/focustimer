import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var timer: TimerStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.96, blue: 0.91), Color(red: 0.93, green: 0.87, blue: 0.80)],
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
                    .tint(timer.endState?.accent ?? TimerStore.ActiveTimer.Kind.focus.accent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!timer.canStart)
                    .accessibilityIdentifier("primaryTimerButton")
                    if timer.canFinish {
                        Button("Done") {
                            timer.done()
                        }
                        .buttonStyle(.bordered)
                        .tint(timer.endState?.accent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("doneButton")
                    }
                    if let hint = timer.alertsHint {
                        Label(hint, systemImage: "bell.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("alertsDeniedHint")
                    }
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Focus / Break Timer")
                    .font(.title2.bold())
                Text("Run Focus, confirm, then run Break.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
    }

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
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.brown.opacity(0.18))
        }
        // Quieter while Focus waits for Break confirmation, so the next action stands out.
        .opacity(timer.endState == .focusComplete ? 0.6 : 1)
    }

    private func durationRow(
        title: String,
        seconds: Binding<Int>,
        range: ClosedRange<Int>,
        kind: TimerStore.ActiveTimer.Kind
    ) -> some View {
        let active = timer.activeTimer?.kind == kind ? timer.activeTimer : nil
        return Stepper(value: seconds, in: range, step: 60) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(active.map { AnyShapeStyle($0.kind.accent) } ?? AnyShapeStyle(.secondary))
                Text("\(seconds.wrappedValue / 60) min")
                    .font(.headline)
            }
        }
        .disabled(!timer.canEditDurations)
        // The active row is tinted with a bar at its leading edge, lighter while paused.
        .padding(.vertical, 6)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .background {
            if let active {
                RoundedRectangle(cornerRadius: 10)
                    .fill(active.kind.accent.opacity(active.paused ? 0.06 : 0.12))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(active.kind.accent.opacity(active.paused ? 0.45 : 1))
                            .frame(width: 4)
                            .padding(.vertical, 6)
                    }
            }
        }
        .modifier(ActiveRowValue(isActive: active != nil))
    }

    private var statusPanel: some View {
        VStack(spacing: 10) {
            if let endState = timer.endState, let headline = timer.endHeadline {
                Image(systemName: endState.symbolName)
                    .font(.system(size: 56))
                    .foregroundStyle(endState.accent)
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
                    .foregroundStyle(active.kind.accent)
                    Text(timer.statusTitle.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(active.paused ? AnyShapeStyle(.secondary) : AnyShapeStyle(active.kind.accent))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(timer.activeTimerAccessibilityLabel ?? active.name)
                .accessibilityIdentifier("activeTimerStatus")
                statusMessageText
            } else {
                Text(timer.statusTitle.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(formattedTime)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                statusMessageText
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.62))
                .overlay {
                    if let accent = timer.endState?.accent {
                        RoundedRectangle(cornerRadius: 16).fill(accent.opacity(0.12))
                    } else if let active = timer.activeTimer {
                        RoundedRectangle(cornerRadius: 16).fill(active.kind.accent.opacity(active.paused ? 0.07 : 0.14))
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: cardBorderWidth)
        }
    }

    private var cardBorderColor: Color {
        if let accent = timer.endState?.accent { return accent.opacity(0.5) }
        if let active = timer.activeTimer { return active.kind.accent.opacity(active.paused ? 0.35 : 0.6) }
        return .brown.opacity(0.18)
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
            .foregroundStyle(Color(red: 0.12, green: 0.33, blue: 0.31))
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

    /// Dark enough for white button text at WCAG AA (contrast about 4.9 for amber and 5.3 for green).
    var accent: Color {
        switch self {
        case .focusComplete: Color(red: 0.66, green: 0.37, blue: 0.06)
        case .breakComplete: Color(red: 0.18, green: 0.48, blue: 0.27)
        }
    }
}

/// Adds "active" to the highlighted duration row, leaving the other row's own value untouched.
private struct ActiveRowValue: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.accessibilityValue("active")
        } else {
            content
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

    /// Teal for Focus, as on the Start button; a sage for Break that leads into the "Cycle complete" green.
    /// Both meet WCAG AA for large text on the tinted card (see the I23 spec).
    var accent: Color {
        switch self {
        case .focus: Color(red: 0.16, green: 0.44, blue: 0.42)
        case .breakTime: Color(red: 0.28, green: 0.44, blue: 0.26)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerStore.shared)
}
