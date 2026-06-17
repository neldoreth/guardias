import SwiftUI

struct MonthSectionView: View {
    @Environment(GuardiasStore.self) private var store
    let month: Int
    let year: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Month header
            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            // Week rows
            VStack(spacing: 3) {
                ForEach(weeksInMonth(), id: \.self) { weekStart in
                    WeekRowView(weekStart: weekStart)
                }
            }
        }
    }

    // MARK: – Helpers

    private var monthTitle: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }

    private func weeksInMonth() -> [Date] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = Calendar.current.date(from: components),
              let lastDay = Calendar.current.date(
                byAdding: DateComponents(month: 1, day: -1), to: firstDay
              ) else { return [] }

        var weeks: [Date] = []
        var current = firstDay.startOfWeek

        while current <= lastDay {
            let weekEnd = current.endOfWeek
            // Include week if it overlaps with this month
            if weekEnd >= firstDay {
                weeks.append(current)
            }
            guard let next = Calendar.isoMonday.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }

        return weeks
    }
}
