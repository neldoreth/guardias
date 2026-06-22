import Foundation

struct AppData: Codable {
    var workers: [Worker] = []
    var manualAssignments: [GuardAssignment] = []
    /// Manually set vacation days. Keys are workerId.uuidString.
    var vacations: [String: [Date]] = [:]
    /// Vacation days imported from Bizneo HR. Keys are workerId.uuidString.
    var bizneoVacations: [String: [Date]] = [:]
    /// Weeks synced to Microsoft 365 calendar. Keys are ISO weekStart (yyyy-MM-dd), values are MS Graph event IDs.
    var m365SyncedWeeks: [String: String] = [:]
    var settings: AppSettings = AppSettings()
    var version: String = "1.0"

    func vacationDays(for workerId: UUID) -> [Date] {
        vacations[workerId.uuidString] ?? []
    }

    mutating func setVacationDays(_ days: [Date], for workerId: UUID) {
        vacations[workerId.uuidString] = days.map { $0.startOfDay }
    }

    func bizneoVacationDays(for workerId: UUID) -> [Date] {
        bizneoVacations[workerId.uuidString] ?? []
    }

    mutating func setBizneoVacationDays(_ days: [Date], for workerId: UUID) {
        bizneoVacations[workerId.uuidString] = days.map { $0.startOfDay }
    }
}

struct AppSettings: Codable {
    // MARK: Schedule settings
    var avoidGuardWeekBeforeVacation: Bool = false
    var scheduleStartDate: Date = {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()
    var scheduleEndDate: Date = {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }()

    // MARK: Bizneo HR
    var bizneoInstance: String = ""
    var bizneoToken: String = ""

    // MARK: Microsoft 365
    var m365ClientId: String = ""
    var m365TenantId: String = ""
    var m365CalendarName: String = "Guardias ClickEZ"
    var m365AccessToken: String = ""
    var m365RefreshToken: String = ""
    var m365TokenExpiresAt: Date? = nil
    var m365UserEmail: String = ""
    var m365CalendarId: String = ""

    var m365IsConnected: Bool { !m365AccessToken.isEmpty && !m365UserEmail.isEmpty }
}
