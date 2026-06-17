import SwiftUI

struct ManualAssignSheet: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let weekStart: Date
    @State private var selectedWorkerId: UUID? = nil

    private var currentAssignment: GuardAssignment? {
        store.assignment(for: weekStart)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Semana") {
                    LabeledContent("Período") {
                        Text(weekRangeText)
                            .foregroundStyle(.secondary)
                    }
                    if let assignment = currentAssignment, let worker = store.worker(id: assignment.workerId) {
                        LabeledContent("Guardia actual") {
                            HStack {
                                Circle().fill(worker.color).frame(width: 8, height: 8)
                                Text(worker.name)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Asignar trabajador") {
                    Picker("Trabajador", selection: $selectedWorkerId) {
                        Text("Sin guardia")
                            .tag(Optional<UUID>.none)
                        ForEach(store.appData.workers) { worker in
                            HStack {
                                Circle().fill(worker.color).frame(width: 10, height: 10)
                                Text(worker.name)
                            }
                            .tag(Optional(worker.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Las asignaciones manuales prevalecen sobre la rotación automática.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Asignación manual")
            .onAppear {
                selectedWorkerId = currentAssignment?.workerId
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let id = selectedWorkerId {
                            store.setManualAssignment(weekStart: weekStart, workerId: id)
                        } else {
                            store.removeManualAssignment(weekStart: weekStart)
                        }
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 380)
    }

    private var weekRangeText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "d 'de' MMMM yyyy"
        let start = fmt.string(from: weekStart)
        let end = fmt.string(from: weekStart.endOfWeek)
        return "\(start) – \(end)"
    }
}
