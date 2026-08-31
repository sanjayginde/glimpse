import SwiftUI

struct CalendarDay: Identifiable {
    let id: String
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let weekdayIndex: Int  // 0=Sun, 1=Mon, ..., 6=Sat
}

struct CalendarWeekRow: Identifiable {
    let id: Int
    let weekNumber: Int
    let days: [CalendarDay]
}

func buildWeekRows(for monthStart: Date, firstWeekday: Int = 1) -> [CalendarWeekRow] {
    var cal = Calendar.current
    cal.firstWeekday = firstWeekday

    guard let monthRange = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
    let daysInMonth = monthRange.count

    let systemWeekday = cal.component(.weekday, from: monthStart)  // 1=Sun..7=Sat
    let leadingCount = (systemWeekday - firstWeekday + 7) % 7

    var cells: [CalendarDay] = []

    if leadingCount > 0, let prevEnd = cal.date(byAdding: .day, value: -1, to: monthStart) {
        let prevDay = cal.component(.day, from: prevEnd)
        for i in stride(from: leadingCount - 1, through: 0, by: -1) {
            cells.append(.init(id: "p\(prevDay - i)", dayNumber: prevDay - i,
                               isCurrentMonth: false, isToday: false, weekdayIndex: 0))
        }
    }

    for d in 1...daysInMonth {
        guard let date = cal.date(byAdding: .day, value: d - 1, to: monthStart) else { continue }
        cells.append(.init(id: "c\(d)", dayNumber: d, isCurrentMonth: true,
                           isToday: cal.isDateInToday(date), weekdayIndex: 0))
    }

    var nd = 1
    while cells.count < 42 {
        cells.append(.init(id: "n\(nd)", dayNumber: nd, isCurrentMonth: false, isToday: false, weekdayIndex: 0))
        nd += 1
    }

    return (0..<6).map { row in
        let slice = Array(cells[(row * 7)..<(row * 7 + 7)])
        let days = slice.enumerated().map { col, day in
            CalendarDay(id: day.id, dayNumber: day.dayNumber,
                        isCurrentMonth: day.isCurrentMonth, isToday: day.isToday,
                        weekdayIndex: (firstWeekday - 1 + col) % 7)
        }
        let dayOffset = (row * 7) - leadingCount
        let rowDate = cal.date(byAdding: .day, value: dayOffset, to: monthStart) ?? monthStart
        return CalendarWeekRow(id: row, weekNumber: cal.component(.weekOfYear, from: rowDate), days: days)
    }
}

struct CalendarView: View {
    @State private var displayedMonth: Date = currentMonthStart()
    @State private var isTitleHovered = false
    @AppStorage("showWeekNumbers") private var showWeekNumbers: Bool = true
    @AppStorage("showDateInIcon") private var showDateInIcon: Bool = true
    @AppStorage("firstWeekday") private var firstWeekday: Int = 1

    private var headerTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var dowLabels: [String] {
        let all = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let offset = firstWeekday - 1
        return Array(all[offset...] + all[..<offset])
    }

    var body: some View {
        let rows = buildWeekRows(for: displayedMonth, firstWeekday: firstWeekday)
        VStack(spacing: 4) {

            // ── Month navigation ──────────────────────────────────────
            HStack {
                navButton(systemImage: "chevron.left") { goMonth(-1) }
                Spacer()
                Button(action: goToToday) {
                    Text(headerTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isTitleHovered ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .help("Go to Today")
                .onHover { isTitleHovered = $0 }
                Spacer()
                navButton(systemImage: "chevron.right") { goMonth(1) }
            }
            .padding(.horizontal, 6)

            // ── Day-of-week header ────────────────────────────────────
            HStack(spacing: 0) {
                if showWeekNumbers {
                    Text("W#")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22)
                }
                ForEach(dowLabels.indices, id: \.self) { i in
                    Text(dowLabels[i])
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34)
                }
            }

            Divider().padding(.vertical, 2)

            // ── Calendar grid ─────────────────────────────────────────
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        if showWeekNumbers {
                            Text("\(row.weekNumber)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: 22, alignment: .trailing)
                        }
                        ForEach(row.days) { day in DayCellView(day: day) }
                    }
                }
            }
            .background(SwipeGestureView(onSwipe: goMonth))

            Divider().padding(.vertical, 2)

            // ── Footer ───────────────────────────────────────────────
            FooterToggleRow(title: "Show Week Numbers", isOn: $showWeekNumbers)
            FooterToggleRow(title: "Show Date in Menu Icon", isOn: $showDateInIcon)

            HStack {
                Text("First Day of Week")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $firstWeekday) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Saturday").tag(7)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)

            Divider()

            FooterActionRow(title: "Quit Glimpse") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: showWeekNumbers ? 274 : 254)
        .onAppear {
            displayedMonth = currentMonthStart()
        }
    }

    // ── Navigation button — .glass on Tahoe, .plain on older ─────────
    @ViewBuilder
    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26, *) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .padding(4)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    private func goMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func goToToday() {
        displayedMonth = currentMonthStart()
    }
}

private func currentMonthStart() -> Date {
    let c = Calendar.current
    return c.date(from: c.dateComponents([.year, .month], from: Date()))!
}

// ── Two-finger trackpad swipe → month navigation ────────────────────────────
// SwiftUI has no swipe gesture for trackpad scroll events, so this wraps an
// NSView that reads NSEvent scroll-wheel deltas directly.

private struct SwipeGestureView: NSViewRepresentable {
    let onSwipe: (Int) -> Void

    func makeNSView(context: Context) -> SwipeCatcherNSView {
        let view = SwipeCatcherNSView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_ nsView: SwipeCatcherNSView, context: Context) {
        nsView.onSwipe = onSwipe
    }
}

private final class SwipeCatcherNSView: NSView {
    var onSwipe: ((Int) -> Void)?

    // Only fire once per continuous gesture, no matter how far the fingers travel.
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var hasFiredForGesture = false
    private let triggerThreshold: CGFloat = 50

    override func scrollWheel(with event: NSEvent) {
        // hasPreciseScrollingDeltas is true for trackpad/Magic Mouse gestures,
        // false for a traditional mouse wheel — filters out non-swipe input.
        guard event.hasPreciseScrollingDeltas else {
            super.scrollWheel(with: event)
            return
        }

        switch event.phase {
        case .began:
            accumulatedX = 0
            accumulatedY = 0
            hasFiredForGesture = false

        case .changed:
            accumulatedX += event.scrollingDeltaX
            accumulatedY += event.scrollingDeltaY

            guard !hasFiredForGesture,
                  abs(accumulatedX) > abs(accumulatedY),
                  abs(accumulatedX) > triggerThreshold else { return }

            hasFiredForGesture = true
            // Swipe left (negative deltaX) advances to next month, matching
            // the page-forward convention used by Calendar/Preview.
            onSwipe?(accumulatedX < 0 ? 1 : -1)

        case .ended, .cancelled:
            accumulatedX = 0
            accumulatedY = 0
            hasFiredForGesture = false

        default:
            break
        }
    }
}

// ── Day cell ──────────────────────────────────────────────────────────────────

struct DayCellView: View {
    let day: CalendarDay

    private var isWeekend: Bool { day.weekdayIndex == 0 || day.weekdayIndex == 6 }

    private var dayFont: Font {
        let weight: Font.Weight = day.isToday ? .semibold : (isWeekend ? .bold : .regular)
        let f = Font.system(size: 13, weight: weight)
        return day.isCurrentMonth ? f : f.italic()
    }

    var body: some View {
        ZStack {
            if day.isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
            }
            Text("\(day.dayNumber)")
                .font(dayFont)
                .foregroundStyle(textColor)
        }
        .frame(width: 34, height: 22)
    }

    private var textColor: Color {
        if day.isToday { return .white }
        if day.isCurrentMonth { return .primary }
        return Color.secondary.opacity(0.5)
    }
}

// ── Footer rows ───────────────────────────────────────────────────────────────

private struct FooterToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    @State private var isHovered = false

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.checkbox)
            .font(.system(size: 13))
            .foregroundStyle(isHovered ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(hoverBackground)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }

    private var hoverBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isHovered ? Color.accentColor : Color.clear)
    }
}

private struct FooterActionRow: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? Color.white : Color.secondary)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(hoverBackground)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var hoverBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isHovered ? Color.accentColor : Color.clear)
    }
}
