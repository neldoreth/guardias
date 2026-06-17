import SwiftUI

struct CalendarGridView: View {
    @Environment(GuardiasStore.self) private var store
    let currentYear: Int

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Worker legend
                if !store.appData.workers.isEmpty {
                    WorkerLegendBar()
                        .padding(.horizontal, 4)
                }

                // 3-column month grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(1...12, id: \.self) { month in
                        MonthCalendarCard(month: month, year: currentYear)
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: – Worker legend

struct WorkerLegendBar: View {
    @Environment(GuardiasStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(store.appData.workers) { worker in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(worker.color)
                            .frame(width: 22, height: 12)
                        Text(worker.name)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}

// MARK: – Month card

struct MonthCalendarCard: View {
    @Environment(GuardiasStore.self) private var store
    let month: Int
    let year: Int

    private let dayLetters = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(monthTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(Array(dayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week rows
            VStack(spacing: 2) {
                ForEach(weeksInMonth(), id: \.self) { weekStart in
                    GridWeekRow(weekStart: weekStart, monthFirstDay: firstDayOfMonth)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: Helpers

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "MMMM"
        return fmt.string(from: firstDayOfMonth).capitalized
    }

    private var firstDayOfMonth: Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = 1
        return Calendar.current.date(from: c) ?? Date()
    }

    private func weeksInMonth() -> [Date] {
        guard let lastDay = Calendar.current.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: firstDayOfMonth
        ) else { return [] }

        var weeks: [Date] = []
        var current = firstDayOfMonth.startOfWeek
        while current <= lastDay {
            if current.endOfWeek >= firstDayOfMonth {
                weeks.append(current)
            }
            guard let next = Calendar.isoMonday.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }
        return weeks
    }
}

// MARK: – Week row inside the grid

struct GridWeekRow: View {
    @Environment(GuardiasStore.self) private var store
    let weekStart: Date
    let monthFirstDay: Date

    private var assignment: GuardAssignment? { store.assignment(for: weekStart) }
    private var worker: Worker? { assignment.flatMap { store.worker(id: $0.workerId) } }
    private var isCurrentWeek: Bool { Date().isSameWeek(as: weekStart) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                let inMonth = Calendar.current.isDate(day, equalTo: monthFirstDay, toGranularity: .month)
                let isVacation = isAnyWorkerVacation(day)

                ZStack {
                    // Vacation indicator
                    if inMonth && isVacation {
                        Circle()
                            .fill(Color.red.opacity(0.25))
                            .padding(2)
                    }

                    Text(inMonth ? "\(Calendar.current.component(.day, from: day))" : "")
                        .font(.caption2)
                        .fontWeight(isCurrentWeek ? .semibold : .regular)
                        .foregroundStyle(inMonth ? (isVacation ? .red : .primary) : .clear)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
        }
        .background {
            if let w = worker {
                RoundedRectangle(cornerRadius: 4)
                    .fill(w.color.opacity(0.18))
            }
        }
        .overlay {
            if isCurrentWeek {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.primary.opacity(0.25), lineWidth: 1.5)
            }
        }
    }

    private func isAnyWorkerVacation(_ date: Date) -> Bool {
        guard let worker else { return false }
        return store.isVacation(date, for: worker)
    }
}
