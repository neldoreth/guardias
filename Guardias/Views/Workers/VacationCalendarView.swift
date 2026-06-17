import SwiftUI

struct VacationCalendarView: View {
    @Environment(GuardiasStore.self) private var store
    let worker: Worker

    private var yearStart: Date {
        let year = Calendar.current.component(.year, from: store.appData.settings.scheduleStartDate)
        return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(0..<12, id: \.self) { offset in
                    if let month = Calendar.current.date(byAdding: .month, value: offset, to: yearStart) {
                        VacationMonthCard(month: month, worker: worker)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Vacaciones — \(worker.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                VacationLegend()
            }
        }
    }
}

// MARK: – Month card

struct VacationMonthCard: View {
    @Environment(GuardiasStore.self) private var store
    let month: Date
    let worker: Worker

    private let dayLetters = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.headline)
                .padding(.bottom, 2)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(dayLetters, id: \.self) { letter in
                    Text(letter)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = daysInMonth()
            let offset = firstWeekdayOffset
            let totalCells = offset + days.count
            let rows = Int(ceil(Double(totalCells) / 7.0))

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let dayIndex = cellIndex - offset
                        if dayIndex >= 0 && dayIndex < days.count {
                            DayCell(date: days[dayIndex], worker: worker)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: month).capitalized
    }

    private var firstWeekdayOffset: Int {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        // weekday: 2=Mon=0 offset, 3=Tue=1, ..., 1=Sun=6
        let weekday = cal.component(.weekday, from: month)
        return (weekday - 2 + 7) % 7
    }

    private func daysInMonth() -> [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { day in
            var c = cal.dateComponents([.year, .month], from: month)
            c.day = day
            return cal.date(from: c)
        }
    }
}

// MARK: – Day cell

struct DayCell: View {
    @Environment(GuardiasStore.self) private var store
    let date: Date
    let worker: Worker

    private var isVacation: Bool { store.isVacation(date, for: worker) }
    private var isOnGuard: Bool {
        store.assignment(for: date.startOfWeek)?.workerId == worker.id
    }
    private var isToday: Bool { date.isToday }

    var body: some View {
        Button {
            store.toggleVacationDay(date, for: worker)
        } label: {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.callout)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(cellForeground)
                .background(cellBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.primary.opacity(0.3), lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(isVacation ? "Quitar vacaciones" : "Marcar como vacaciones")
    }

    private var cellForeground: Color {
        if isVacation { return .red }
        if isOnGuard { return worker.color }
        return .primary
    }

    @ViewBuilder
    private var cellBackground: some View {
        if isVacation {
            Color.red.opacity(0.15)
        } else if isOnGuard {
            worker.color.opacity(0.12)
        } else {
            Color.clear
        }
    }
}

// MARK: – Legend

struct VacationLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            LegendItem(color: .red.opacity(0.15), label: "Vacaciones")
            LegendItem(color: .blue.opacity(0.12), label: "Guardia")
        }
        .font(.caption)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
