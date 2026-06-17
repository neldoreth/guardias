import SwiftUI

struct SwapGuardSheet: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let weekStart: Date
    let currentWorkerId: UUID?

    @State private var selectedWorkerId: UUID? = nil

    private var currentWorker: Worker? {
        currentWorkerId.flatMap { store.worker(id: $0) }
    }

    private var availableWorkers: [Worker] {
        store.appData.workers.filter { $0.id != currentWorkerId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Semana a cambiar") {
                    LabeledContent("Período") {
                        Text(weekRangeText)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Trabajador actual") {
                    if let worker = currentWorker {
                        HStack {
                            Circle().fill(worker.color).frame(width: 10, height: 10)
                            Text(worker.name)
                        }
                    } else {
                        Text("Sin asignación").foregroundStyle(.secondary)
                    }
                }

                Section("Asignar a") {
                    if availableWorkers.isEmpty {
                        Text("No hay otros trabajadores disponibles.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Trabajador", selection: $selectedWorkerId) {
                            ForEach(availableWorkers) { worker in
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
                }

                if let selected = selectedWorkerId, let worker = store.worker(id: selected) {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("\(worker.name) pasará a cubrir la semana del \(weekStartText).")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Cambio de guardia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar cambio") {
                        guard let newId = selectedWorkerId,
                              let oldId = currentWorkerId else { return }
                        store.swapGuard(weekStart: weekStart, originalWorkerId: oldId, newWorkerId: newId)
                        dismiss()
                    }
                    .disabled(selectedWorkerId == nil)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }

    private var weekRangeText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "d 'de' MMMM"
        let start = fmt.string(from: weekStart)
        let end = fmt.string(from: weekStart.endOfWeek)
        return "\(start) – \(end)"
    }

    private var weekStartText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "d 'de' MMMM"
        return fmt.string(from: weekStart)
    }
}
