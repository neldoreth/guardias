import SwiftUI
import UniformTypeIdentifiers

struct WeekRowView: View {
    @Environment(GuardiasStore.self) private var store
    let weekStart: Date

    @State private var showManualAssign = false
    @State private var showSwap = false
    @State private var isDropTargeted = false

    private var assignment: GuardAssignment? { store.assignment(for: weekStart) }
    private var worker: Worker? { assignment.flatMap { store.worker(id: $0.workerId) } }
    private var isCurrentWeek: Bool { Date().isSameWeek(as: weekStart) }

    var body: some View {
        HStack(spacing: 12) {
            // Week range label
            Text(weekRangeText)
                .font(.callout)
                .foregroundStyle(isCurrentWeek ? .primary : .secondary)
                .fontWeight(isCurrentWeek ? .semibold : .regular)
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
        // ── Drop target highlight ─────────────────────────────────────────
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.blue, lineWidth: 2)
            }
        }
        // ── Drag source ───────────────────────────────────────────────────
        .onDrag {
            NSItemProvider(object: weekStart.timeIntervalSince1970.description as NSString)
        }
        // ── Drop target ───────────────────────────────────────────────────
        .onDrop(of: [.plainText], isTargeted: $isDropTargeted, perform: handleDrop)
        // ── Context menu (kept alongside drag) ────────────────────────────
        .contextMenu {
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
        .sheet(isPresented: $showManualAssign) {
            ManualAssignSheet(weekStart: weekStart)
                .environment(store)
        }
        .sheet(isPresented: $showSwap) {
            SwapGuardSheet(weekStart: weekStart, currentWorkerId: assignment?.workerId)
                .environment(store)
        }
    }

    // MARK: – Drag-and-drop handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let str = item as? String,
                  let timestamp = Double(str) else { return }
            let sourceWeek = Date(timeIntervalSince1970: timestamp)
            guard !sourceWeek.isSameWeek(as: weekStart) else { return }
            Task { @MainActor in
                store.swapWeeks(sourceWeek: sourceWeek, targetWeek: weekStart)
            }
        }
        return true
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

// MARK: – Assignment pill

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

                if assignment?.swapInfo != nil {
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
