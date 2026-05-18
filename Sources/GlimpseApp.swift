import SwiftUI
import ServiceManagement

// Updates the menu bar day number at midnight (DST-safe one-shot recursion)
@MainActor
final class DayProvider: ObservableObject {
    @Published var dayString = "\(Calendar.current.component(.day, from: Date()))"
    private var timer: Timer?

    init() { scheduleNextMidnight() }

    private func scheduleNextMidnight() {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()),
              let nextMidnight = cal.date(bySettingHour: 0, minute: 0, second: 5, of: tomorrow)
        else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: nextMidnight.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dayString = "\(Calendar.current.component(.day, from: Date()))"
                self?.scheduleNextMidnight()
            }
        }
    }
}

@main
struct GlimpseApp: App {
    @StateObject private var dayProvider = DayProvider()
    @AppStorage("showDateInIcon") private var showDateInIcon: Bool = true

    init() {
        let service = SMAppService.mainApp
        if service.status == .notRegistered {
            try? service.register()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            CalendarView()
        } label: {
            // Template-rendered — system tints to match menu bar color automatically
            HStack(spacing: 3) {
                Image(systemName: "calendar")
                if showDateInIcon {
                    Text(dayProvider.dayString)
                        .monospacedDigit()
                }
            }
            .font(.system(size: 12))
        }
        .menuBarExtraStyle(.window)
    }
}
