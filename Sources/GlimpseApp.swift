import SwiftUI

// Updates the menu bar day number whenever the calendar day changes
@MainActor
final class DayProvider: ObservableObject {
    @Published var dayString = DayProvider.today()

    init() {
        // NSCalendarDayChanged fires at midnight and on time zone/clock changes. Unlike a
        // countdown Timer, it isn't thrown off by sleep; wake is also observed as a backstop.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    private func refresh() {
        let day = Self.today()
        if day != dayString { dayString = day }
    }

    private static func today() -> String {
        "\(Calendar.current.component(.day, from: Date()))"
    }
}

@main
struct GlimpseApp: App {
    @StateObject private var dayProvider = DayProvider()
    @AppStorage("showDateInIcon") private var showDateInIcon: Bool = true

    var body: some Scene {
        MenuBarExtra {
            CalendarView(dayProvider: dayProvider)
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
