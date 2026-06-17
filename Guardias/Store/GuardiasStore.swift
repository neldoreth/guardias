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
                (worker.id, appData.vacationDays(for: worker.id))
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

    // MARK: – Drag-and-drop week swap

    /// Swaps the guard assignments of two weeks. Both become manual overrides.
    func swapWeeks(sourceWeek: Date, targetWeek: Date) {
        let src = assignment(for: sourceWeek)
        let tgt = assignment(for: targetWeek)
        let swapDate = Date()

        appData.manualAssignments.removeAll {
            $0.weekStart.isSameWeek(as: sourceWeek) || $0.weekStart.isSameWeek(as: targetWeek)
        }

        if let fromId = src?.workerId, let toId = tgt?.workerId {
            // Full mutual swap
            appData.manualAssignments.append(GuardAssignment(
                weekStart: sourceWeek, workerId: toId, isManual: true,
                swapInfo: .init(originalWorkerId: fromId, newWorkerId: toId, swapDate: swapDate)
            ))
            appData.manualAssignments.append(GuardAssignment(
                weekStart: targetWeek, workerId: fromId, isManual: true,
                swapInfo: .init(originalWorkerId: toId, newWorkerId: fromId, swapDate: swapDate)
            ))
        } else if let fromId = src?.workerId {
            // Move source worker to target week
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
