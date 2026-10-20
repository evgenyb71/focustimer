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
                    .tint(Color(red: 0.16, green: 0.44, blue: 0.42))
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!timer.canStart)
                    .accessibilityIdentifier("primaryTimerButton")
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
            Button {
                timer.cancel()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Cancel and reset")
        }
        .buttonStyle(.bordered)
    }

    private var durationPanel: some View {
        VStack(spacing: 16) {
            durationRow(
                title: "Focus Timer",
                seconds: $timer.configuration.durationASeconds,
                range: TimerStore.Configuration.focusRange
            )
            Divider()
            durationRow(
                title: "Break Timer",
                seconds: $timer.configuration.durationBSeconds,
                range: TimerStore.Configuration.breakRange
            )
        }
        .padding()
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.brown.opacity(0.18))
        }
    }

    private func durationRow(
        title: String,
        seconds: Binding<Int>,
        range: ClosedRange<Int>,
    ) -> some View {
        Stepper(value: seconds, in: range, step: 60) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(seconds.wrappedValue / 60) min")
                    .font(.headline)
            }
        }
        .disabled(!timer.canEditDurations)
    }

    private var statusPanel: some View {
        VStack(spacing: 10) {
            Text(timer.statusTitle.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formattedTime)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(timer.statusMessage)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.12, green: 0.33, blue: 0.31))
                .multilineTextAlignment(.center)
                .frame(minHeight: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.brown.opacity(0.18))
        }
    }

    private var formattedTime: String {
        guard let total = timer.displayedSeconds else { return "--:--" }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerStore.shared)
}
