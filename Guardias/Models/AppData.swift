import Foundation

struct AppData: Codable {
    var workers: [Worker] = []
    /// Only explicitly overridden weeks (manual or swap). Automatic rotation is not stored.
    var manualAssignments: [GuardAssignment] = []
    /// Keys are workerId.uuidString for JSON compatibility.
    var vacations: [String: [Date]] = [:]
    var settings: AppSettings = AppSettings()
    var version: String = "1.0"

    func vacationDays(for workerId: UUID) -> [Date] {
        vacations[workerId.uuidString] ?? []
    }

    mutating func setVacationDays(_ days: [Date], for workerId: UUID) {
        vacations[workerId.uuidString] = days.map { $0.startOfDay }
    }
}

struct AppSettings: Codable {
    /// When active, also blocks the week before a worker's vacation.
    var avoidGuardWeekBeforeVacation: Bool = false
    var scheduleStartDate: Date = {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()
    var scheduleEndDate: Date = {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }()
}
