import Foundation

struct GuardAssignment: Identifiable, Codable, Hashable {
    var id: UUID
    /// Always stored as the Monday of the guard week.
    var weekStart: Date
    var workerId: UUID
    /// True if the user explicitly assigned this week (overrides rotation).
    var isManual: Bool
    /// Non-nil when this assignment was the result of a swap.
    var swapInfo: SwapInfo?

    init(
        id: UUID = UUID(),
        weekStart: Date,
        workerId: UUID,
        isManual: Bool = false,
        swapInfo: SwapInfo? = nil
    ) {
        self.id = id
        self.weekStart = weekStart.startOfWeek
        self.workerId = workerId
        self.isManual = isManual
        self.swapInfo = swapInfo
    }

    struct SwapInfo: Codable, Hashable {
        /// The worker who originally had this week.
        var originalWorkerId: UUID
        /// The worker who now covers this week.
        var newWorkerId: UUID
        var swapDate: Date
    }
}
