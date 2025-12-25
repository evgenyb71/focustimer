import SwiftUI
import UserNotifications

@MainActor
final class TimerViewModel: ObservableObject {
    enum Phase: String {
        case idle
        case runningFocus
        case waitingForConfirm
        case runningBreak
        case pausedFocus
        case pausedBreak
    }

    struct Config: Codable {
        var focusMinutes: Int = 25
        var breakMinutes: Int = 5
    }

    struct State: Codable {
        var phase: Phase = .idle
        var endDate: Date? = nil
        var remainingSeconds: TimeInterval? = nil
    }

    @Published var config = Config()
    @Published var state = State()
    @Published var remainingDisplay: String = "--:--"
    @Published var statusMessage: String = "Ready"

    private var ticker: Timer?
    private let storageKeyConfig = "config"
    private let storageKeyState = "state"

    init() {
        loadStored()
        resumeIfNeeded()
        startTicking()
    }

    func start() {
        guard state.phase == .idle else { return }
        guard config.focusMinutes > 0, config.breakMinutes > 0 else { return }
        state.phase = .runningFocus
        state.endDate = Date().addingTimeInterval(TimeInterval(config.focusMinutes * 60))
        state.remainingSeconds = nil
        statusMessage = "Focus running"
        persist()
        scheduleCompletionNotification(for: .runningFocus)
    }

    func confirmStartBreak() {
        guard state.phase == .waitingForConfirm else { return }
        state.phase = .runningBreak
        state.endDate = Date().addingTimeInterval(TimeInterval(config.breakMinutes * 60))
        state.remainingSeconds = nil
        statusMessage = "Break running"
        persist()
        scheduleCompletionNotification(for: .runningBreak)
    }

    func pauseOrResume() {
        switch state.phase {
        case .runningFocus, .runningBreak:
            guard let end = state.endDate else { return }
            let remaining = max(1, end.timeIntervalSinceNow)
            state.remainingSeconds = remaining
            state.endDate = nil
            state.phase = state.phase == .runningFocus ? .pausedFocus : .pausedBreak
            statusMessage = "Paused"
            persist()
        case .pausedFocus, .pausedBreak:
            guard let remaining = state.remainingSeconds else { return }
            state.endDate = Date().addingTimeInterval(remaining)
            state.remainingSeconds = nil
            state.phase = state.phase == .pausedFocus ? .runningFocus : .runningBreak
            statusMessage = state.phase == .runningFocus ? "Focus running" : "Break running"
            persist()
            scheduleCompletionNotification(for: state.phase)
        default:
            break
        }
    }

    func cancel() {
        state = State()
        statusMessage = "Ready"
        persist()
    }

    private func loadStored() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: storageKeyConfig),
           let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            config = cfg
        }
        if let data = defaults.data(forKey: storageKeyState),
           let st = try? JSONDecoder().decode(State.self, from: data) {
            state = st
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: storageKeyConfig)
        }
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: storageKeyState)
        }
    }

    private func resumeIfNeeded() {
        switch state.phase {
        case .runningFocus, .runningBreak:
            if let end = state.endDate, end <= Date() {
                handleCompletion()
            }
        default:
            break
        }
    }

    private func startTicking() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        switch state.phase {
        case .runningFocus, .runningBreak:
            guard let end = state.endDate else { return }
            let remaining = max(0, end.timeIntervalSinceNow)
            remainingDisplay = format(seconds: remaining)
            if remaining <= 0 {
                handleCompletion()
            }
        case .pausedFocus, .pausedBreak:
            remainingDisplay = format(seconds: state.remainingSeconds ?? 0)
        case .waitingForConfirm:
            remainingDisplay = "00:00"
        case .idle:
            remainingDisplay = "--:--"
        }
    }

    private func handleCompletion() {
        switch state.phase {
        case .runningFocus:
            state.phase = .waitingForConfirm
            state.endDate = nil
            statusMessage = "Focus done. Start Break?"
            persist()
            scheduleCompletionNotification(for: .waitingForConfirm)
        case .runningBreak:
            state = State()
            statusMessage = "Break done"
            persist()
            scheduleCompletionNotification(for: .idle)
        default:
            break
        }
    }

    private func format(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func scheduleCompletionNotification(for phase: Phase) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        center.removePendingNotificationRequests(withIdentifiers: ["focusComplete", "breakComplete"])
        let content = UNMutableNotificationContent()
        switch phase {
        case .runningFocus:
            content.title = "Focus complete"
            content.body = "Tap to start Break."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: state.endDate?.timeIntervalSinceNow ?? 1, repeats: false)
            let request = UNNotificationRequest(identifier: "focusComplete", content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        case .runningBreak:
            content.title = "Break complete"
            content.body = "Sequence finished."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: state.endDate?.timeIntervalSinceNow ?? 1, repeats: false)
            let request = UNNotificationRequest(identifier: "breakComplete", content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        case .waitingForConfirm:
            content.title = "Focus complete"
            content.body = "Start Break when ready."
            let request = UNNotificationRequest(identifier: "focusComplete", content: content, trigger: nil)
            center.add(request, withCompletionHandler: nil)
        case .idle:
            content.title = "Break complete"
            content.body = "Sequence finished."
            let request = UNNotificationRequest(identifier: "breakComplete", content: content, trigger: nil)
            center.add(request, withCompletionHandler: nil)
        default:
            break
        }
    }
}

struct ContentView: View {
    @StateObject private var model = TimerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus / Break Timer")
                        .font(.title3).bold()
                    Text("Run Focus, confirm, then run Break.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { model.pauseOrResume() }) {
                        Text(model.state.phase == .pausedFocus || model.state.phase == .pausedBreak ? "▶" : "||")
                            .font(.headline)
                    }
                    .disabled(model.state.phase == .idle || model.state.phase == .waitingForConfirm)

                    Button(action: { model.cancel() }) {
                        Text("x").font(.headline)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus (min)").font(.caption).foregroundColor(.secondary)
                    Stepper(value: $model.config.focusMinutes, in: 1...240, step: 1) {
                        Text("\(model.config.focusMinutes) min")
                    }
                    Text("Break (min)").font(.caption).foregroundColor(.secondary)
                    Stepper(value: $model.config.breakMinutes, in: 1...120, step: 1) {
                        Text("\(model.config.breakMinutes) min")
                    }
                }
                Spacer()
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)

            VStack(spacing: 8) {
                Text(model.statusMessage).font(.caption).foregroundColor(.secondary)
                Text(model.remainingDisplay).font(.system(size: 42, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Button(action: {
                if model.state.phase == .waitingForConfirm {
                    model.confirmStartBreak()
                } else {
                    model.start()
                }
            }) {
                Text(model.state.phase == .waitingForConfirm ? "Start Break" : "Start Focus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(buttonDisabled)

            Spacer()
        }
        .padding()
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private var buttonDisabled: Bool {
        switch model.state.phase {
        case .idle:
            return false
        case .waitingForConfirm:
            return false
        default:
            return true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
