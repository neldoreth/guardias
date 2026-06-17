import SwiftUI

struct WeekRowView: View {
    @Environment(GuardiasStore.self) private var store
    let weekStart: Date

    @State private var showManualAssign = false
    @State private var showSwap = false

    private var assignment: GuardAssignment? { store.assignment(for: weekStart) }
    private var worker: Worker? { assignment.flatMap { store.worker(id: $0.workerId) } }
    private var isCurrentWeek: Bool { Date().isSameWeek(as: weekStart) }

    var body: some View {
        HStack(spacing: 12) {
            // Week range label
            VStack(alignment: .leading, spacing: 2) {
                Text(weekRangeText)
                    .font(.callout)
                    .foregroundStyle(isCurrentWeek ? .primary : .secondary)
                    .fontWeight(isCurrentWeek ? .semibold : .regular)
            }
            .frame(width: 160, alignment: .leading)

            // Assignment pill
            if let worker {
                AssignmentPill(worker: worker, assignment: assignment)
            } else {
                Text("Sin guardia")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }

            Spacer()

            // Current week indicator
            if isCurrentWeek {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            if isCurrentWeek {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showManualAssign) {
            ManualAssignSheet(weekStart: weekStart)
                .environment(store)
        }
        .sheet(isPresented: $showSwap) {
            SwapGuardSheet(weekStart: weekStart, currentWorkerId: assignment?.workerId)
                .environment(store)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            showManualAssign = true
        } label: {
            Label("Asignar manualmente…", systemImage: "hand.point.up.left")
        }

        Button {
            showSwap = true
        } label: {
            Label("Cambio de guardia…", systemImage: "arrow.2.squarepath")
        }

        if assignment?.isManual == true {
            Divider()
            Button(role: .destructive) {
                store.removeManualAssignment(weekStart: weekStart)
            } label: {
                Label("Eliminar asignación manual", systemImage: "trash")
            }
        }
    }

    // MARK: – Formatting

    private var weekRangeText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "d MMM"
        let start = fmt.string(from: weekStart)
        let end = fmt.string(from: weekStart.endOfWeek)
        return "\(start) – \(end)"
    }
}

struct AssignmentPill: View {
    let worker: Worker
    let assignment: GuardAssignment?

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(worker.color)
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(worker.name)
                    .font(.callout)
                    .fontWeight(.medium)

                if let swap = assignment?.swapInfo,
                   let _ = swap.originalWorkerId as UUID? {
                    Text("Cambio")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if assignment?.isManual == true {
                    Text("Manual")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(worker.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(worker.color.opacity(0.25), lineWidth: 1)
        )
    }
}
