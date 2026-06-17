import Foundation

extension Calendar {
    static var isoMonday: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "es_ES")
        return cal
    }
}

extension Date {
    var startOfWeek: Date {
        let cal = Calendar.isoMonday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components) ?? self
    }

    var endOfWeek: Date {
        Calendar.isoMonday.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isSameWeek(as other: Date) -> Bool {
        startOfWeek.isSameDay(as: other.startOfWeek)
    }

    /// Returns the 7 days of the week (Mon–Sun) containing this date.
    var weekdays: [Date] {
        let start = startOfWeek
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
