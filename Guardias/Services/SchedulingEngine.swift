import Foundation

struct SchedulingEngine {

    // MARK: – Public API

    static func compute(
        workers: [Worker],
        manualAssignments: [GuardAssignment],
        vacations: [UUID: [Date]],
        settings: AppSettings
    ) -> [GuardAssignment] {
        guard !workers.isEmpty else { return [] }

        let weeks = allWeeks(from: settings.scheduleStartDate, to: settings.scheduleEndDate)
        var result: [GuardAssignment] = []
        var rotationIndex = 0
        var lastWorkerId: UUID? = nil

        // Index manual assignments by their week start for O(1) lookup
        let manualByWeek: [Date: GuardAssignment] = Dictionary(
            manualAssignments.map { ($0.weekStart.startOfWeek, $0) },
            uniquingKeysWith: { _, last in last }
        )

        for weekStart in weeks {
            let key = weekStart.startOfWeek

            // Manual/swap assignment takes priority
            if let manual = manualByWeek[key] {
                result.append(manual)
                lastWorkerId = manual.workerId
                continue
            }

            // First pass: find available worker that is NOT the previous week's worker
            var assigned: Worker? = nil
            for offset in 0..<workers.count {
                let idx = (rotationIndex + offset) % workers.count
                let candidate = workers[idx]
                if candidate.id != lastWorkerId,
                   isAvailable(candidate, weekStart: weekStart, vacations: vacations, settings: settings) {
                    assigned = candidate
                    rotationIndex = (idx + 1) % workers.count
                    break
                }
            }

            // Second pass: allow consecutive guard if no other option
            if assigned == nil {
                for offset in 0..<workers.count {
                    let idx = (rotationIndex + offset) % workers.count
                    let candidate = workers[idx]
                    if isAvailable(candidate, weekStart: weekStart, vacations: vacations, settings: settings) {
                        assigned = candidate
                        rotationIndex = (idx + 1) % workers.count
                        break
                    }
                }
            }

            if let worker = assigned {
                result.append(GuardAssignment(weekStart: weekStart, workerId: worker.id, isManual: false))
                lastWorkerId = worker.id
            }
            // If no worker available, the week has no guard
        }

        return result
    }

    // MARK: – Private helpers

    private static func isAvailable(
        _ worker: Worker,
        weekStart: Date,
        vacations: [UUID: [Date]],
        settings: AppSettings
    ) -> Bool {
        let workerVacations = vacations[worker.id] ?? []
        guard !workerVacations.isEmpty else { return true }

        // Block if any vacation day falls within Mon–Sun of this week
        if weekStart.weekdays.contains(where: { day in workerVacations.contains { $0.isSameDay(as: day) } }) {
            return false
        }

        // Optionally block the week before vacation
        if settings.avoidGuardWeekBeforeVacation,
           let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart),
           nextWeek.weekdays.contains(where: { day in workerVacations.contains { $0.isSameDay(as: day) } }) {
            return false
        }

        return true
    }

    private static func allWeeks(from startDate: Date, to endDate: Date) -> [Date] {
        var weeks: [Date] = []
        var current = startDate.startOfWeek
        while current <= endDate {
            weeks.append(current)
            guard let next = Calendar.isoMonday.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }
        return weeks
    }
}
