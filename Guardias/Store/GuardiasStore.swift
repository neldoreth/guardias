import Foundation
import Observation

@Observable
@MainActor
final class GuardiasStore {

    // MARK: – State

    var appData: AppData = AppData()
    /// Full computed schedule (manual + auto). Rebuilt whenever data changes.
    private(set) var schedule: [GuardAssignment] = []

    // MARK: – Persistence

    private let dataURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Guardias", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    init() {
        load()
        recompute()
    }

    // MARK: – Recompute

    func recompute() {
        let vacations = Dictionary(
            uniqueKeysWithValues: appData.workers.map { worker in
                let manual = Set(appData.vacationDays(for: worker.id).map { $0.startOfDay })
                let bizneo = Set(appData.bizneoVacationDays(for: worker.id).map { $0.startOfDay })
                return (worker.id, Array(manual.union(bizneo)))
            }
        )
        schedule = SchedulingEngine.compute(
            workers: appData.workers,
            manualAssignments: appData.manualAssignments,
            vacations: vacations,
            settings: appData.settings
        )
    }

    // MARK: – Persistence

    func save() {
        do {
            let data = try encoder.encode(appData)
            try data.write(to: dataURL, options: .atomic)
        } catch {
            print("[Guardias] Save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: dataURL.path),
              let data = try? Data(contentsOf: dataURL),
              let loaded = try? decoder.decode(AppData.self, from: data) else { return }
        appData = loaded
    }

    // MARK: – Workers

    func addWorker(name: String) {
        let colorIndex = appData.workers.count % Worker.palette.count
        appData.workers.append(Worker(name: name, colorIndex: colorIndex))
        saveAndRecompute()
    }

    func removeWorker(_ worker: Worker) {
        appData.workers.removeAll { $0.id == worker.id }
        appData.manualAssignments.removeAll { $0.workerId == worker.id }
        appData.vacations.removeValue(forKey: worker.id.uuidString)
        appData.bizneoVacations.removeValue(forKey: worker.id.uuidString)
        saveAndRecompute()
    }

    func updateWorker(_ worker: Worker) {
        guard let idx = appData.workers.firstIndex(where: { $0.id == worker.id }) else { return }
        appData.workers[idx] = worker
        saveAndRecompute()
    }

    func moveWorkers(from source: IndexSet, to destination: Int) {
        appData.workers.move(fromOffsets: source, toOffset: destination)
        saveAndRecompute()
    }

    // MARK: – Vacations

    func toggleVacationDay(_ date: Date, for worker: Worker) {
        var days = appData.vacationDays(for: worker.id)
        if let idx = days.firstIndex(where: { $0.isSameDay(as: date) }) {
            days.remove(at: idx)
        } else {
            days.append(date.startOfDay)
        }
        appData.setVacationDays(days, for: worker.id)
        saveAndRecompute()
    }

    func vacationDays(for worker: Worker) -> [Date] {
        appData.vacationDays(for: worker.id)
    }

    func isVacation(_ date: Date, for worker: Worker) -> Bool {
        appData.vacationDays(for: worker.id).contains { $0.isSameDay(as: date) }
    }

    func isBizneoVacation(_ date: Date, for worker: Worker) -> Bool {
        appData.bizneoVacationDays(for: worker.id).contains { $0.isSameDay(as: date) }
    }

    /// Adds all days in [startDate, endDate] as vacation (inclusive). Safe to call with startDate == endDate.
    func addVacationRange(from startDate: Date, to endDate: Date, for worker: Worker) {
        var days = appData.vacationDays(for: worker.id)
        var current = min(startDate, endDate).startOfDay
        let end = max(startDate, endDate).startOfDay
        while current <= end {
            if !days.contains(where: { $0.isSameDay(as: current) }) {
                days.append(current)
            }
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        appData.setVacationDays(days, for: worker.id)
        saveAndRecompute()
    }

    /// Removes a single vacation day.
    func removeVacationDay(_ date: Date, for worker: Worker) {
        var days = appData.vacationDays(for: worker.id)
        days.removeAll { $0.isSameDay(as: date) }
        appData.setVacationDays(days, for: worker.id)
        saveAndRecompute()
    }

    /// Removes all vacation days in [startDate, endDate] (inclusive).
    func removeVacationRange(from startDate: Date, to endDate: Date, for worker: Worker) {
        let lo = min(startDate, endDate).startOfDay
        let hi = max(startDate, endDate).startOfDay
        var days = appData.vacationDays(for: worker.id)
        days.removeAll { day in
            let d = day.startOfDay
            return d >= lo && d <= hi
        }
        appData.setVacationDays(days, for: worker.id)
        saveAndRecompute()
    }

    // MARK: – Microsoft 365 sync

    func isM365Synced(weekStart: Date) -> Bool {
        appData.m365SyncedWeeks[isoWeekKey(weekStart)] != nil
    }

    func syncWeekToM365(weekStart: Date) async throws {
        guard let assign = assignment(for: weekStart),
              let worker = worker(id: assign.workerId) else {
            throw M365Error.noAssignment
        }
        let token = try await validM365AccessToken()
        let calId = appData.settings.m365CalendarId
        guard !calId.isEmpty else { throw M365Error.calendarNotFound(appData.settings.m365CalendarName) }
        let eventId = try await M365Service.createWeekEvent(
            weekStart: weekStart.startOfWeek,
            workerName: worker.name,
            calendarId: calId,
            accessToken: token
        )
        appData.m365SyncedWeeks[isoWeekKey(weekStart)] = eventId
        save()
    }

    func unsyncWeekFromM365(weekStart: Date) async throws {
        let key = isoWeekKey(weekStart)
        guard let eventId = appData.m365SyncedWeeks[key] else { return }
        let token = try await validM365AccessToken()
        try await M365Service.deleteEvent(eventId: eventId, accessToken: token)
        appData.m365SyncedWeeks.removeValue(forKey: key)
        save()
    }

    /// Returns a valid access token, refreshing if it's expired or close to expiry.
    func validM365AccessToken() async throws -> String {
        let s = appData.settings
        guard s.m365IsConnected else { throw M365Error.notConnected }
        if !s.m365AccessToken.isEmpty,
           let expiry = s.m365TokenExpiresAt,
           expiry.timeIntervalSinceNow > 300 {
            return s.m365AccessToken
        }
        let (newAccess, newRefresh, expiresIn) = try await M365Service.refreshAccessToken(
            refreshToken: s.m365RefreshToken,
            clientId: s.m365ClientId,
            tenantId: s.m365TenantId
        )
        var updated = appData.settings
        updated.m365AccessToken = newAccess
        updated.m365RefreshToken = newRefresh
        updated.m365TokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        appData.settings = updated
        save()
        return newAccess
    }

    private func isoWeekKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date.startOfWeek)
    }

    // MARK: – Bizneo sync

    func syncBizneoVacations(for worker: Worker) async throws {
        let instance = appData.settings.bizneoInstance
        let token = appData.settings.bizneoToken
        guard !instance.isEmpty, !token.isEmpty else {
            throw BizneoSyncError.notConfigured
        }
        guard let userId = worker.bizneoUserId else {
            throw BizneoSyncError.noUserLinked
        }
        let days = try await BizneoService.fetchVacationDays(
            userId: userId,
            from: appData.settings.scheduleStartDate,
            to: appData.settings.scheduleEndDate,
            instance: instance,
            token: token
        )
        appData.setBizneoVacationDays(days, for: worker.id)
        saveAndRecompute()
    }

    // MARK: – Manual assignments

    func setManualAssignment(weekStart: Date, workerId: UUID) {
        let assignment = GuardAssignment(weekStart: weekStart, workerId: workerId, isManual: true)
        appData.manualAssignments.removeAll { $0.weekStart.isSameWeek(as: weekStart) }
        appData.manualAssignments.append(assignment)
        saveAndRecompute()
    }

    func removeManualAssignment(weekStart: Date) {
        appData.manualAssignments.removeAll { $0.weekStart.isSameWeek(as: weekStart) }
        saveAndRecompute()
    }

    // MARK: – Swap

    func swapGuard(weekStart: Date, originalWorkerId: UUID, newWorkerId: UUID) {
        let swapInfo = GuardAssignment.SwapInfo(
            originalWorkerId: originalWorkerId,
            newWorkerId: newWorkerId,
            swapDate: Date()
        )
        let assignment = GuardAssignment(
            weekStart: weekStart,
            workerId: newWorkerId,
            isManual: true,
            swapInfo: swapInfo
        )
        appData.manualAssignments.removeAll { $0.weekStart.isSameWeek(as: weekStart) }
        appData.manualAssignments.append(assignment)
        saveAndRecompute()
    }

    /// Swaps the guard assignments of two weeks. Both become manual overrides.
    func swapWeeks(sourceWeek: Date, targetWeek: Date) {
        let src = assignment(for: sourceWeek)
        let tgt = assignment(for: targetWeek)
        let swapDate = Date()

        appData.manualAssignments.removeAll {
            $0.weekStart.isSameWeek(as: sourceWeek) || $0.weekStart.isSameWeek(as: targetWeek)
        }

        if let fromId = src?.workerId, let toId = tgt?.workerId {
            appData.manualAssignments.append(GuardAssignment(
                weekStart: sourceWeek, workerId: toId, isManual: true,
                swapInfo: .init(originalWorkerId: fromId, newWorkerId: toId, swapDate: swapDate)
            ))
            appData.manualAssignments.append(GuardAssignment(
                weekStart: targetWeek, workerId: fromId, isManual: true,
                swapInfo: .init(originalWorkerId: toId, newWorkerId: fromId, swapDate: swapDate)
            ))
        } else if let fromId = src?.workerId {
            appData.manualAssignments.append(GuardAssignment(
                weekStart: targetWeek, workerId: fromId, isManual: true
            ))
        }

        saveAndRecompute()
    }

    // MARK: – Lookup helpers

    func assignment(for weekStart: Date) -> GuardAssignment? {
        schedule.first { $0.weekStart.isSameWeek(as: weekStart) }
    }

    func worker(id: UUID) -> Worker? {
        appData.workers.first { $0.id == id }
    }

    // MARK: – Backup

    func exportData() -> Data? {
        try? encoder.encode(appData)
    }

    func importData(_ data: Data) -> Bool {
        guard let loaded = try? decoder.decode(AppData.self, from: data) else { return false }
        appData = loaded
        saveAndRecompute()
        return true
    }

    // MARK: – Settings shortcut

    func updateSettings(_ settings: AppSettings) {
        appData.settings = settings
        saveAndRecompute()
    }

    // MARK: – Private

    private func saveAndRecompute() {
        save()
        recompute()
    }
}

// MARK: – Errors

enum BizneoSyncError: LocalizedError {
    case notConfigured
    case noUserLinked

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Configura la instancia y el token de Bizneo en Ajustes."
        case .noUserLinked: return "Vincula este trabajador a un usuario de Bizneo en sus ajustes."
        }
    }
}
