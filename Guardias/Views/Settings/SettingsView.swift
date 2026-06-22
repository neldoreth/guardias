import SwiftUI

struct SettingsView: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var newWorkerName = ""
    @State private var workerToEdit: Worker? = nil
    @State private var showM365Connect = false

    var body: some View {
        NavigationStack {
            Form {
                workersSection
                guardSettingsSection
                scheduleRangeSection
                bizneoSection
                m365Section
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 600)
        .sheet(item: $workerToEdit) { worker in
            EditWorkerView(worker: worker)
                .environment(store)
        }
        .sheet(isPresented: $showM365Connect) {
            M365ConnectView()
                .environment(store)
        }
    }

    // MARK: – Sections

    private var workersSection: some View {
        Section {
            ForEach(store.appData.workers) { worker in
                WorkerRow(worker: worker) {
                    workerToEdit = worker
                } onDelete: {
                    store.removeWorker(worker)
                }
            }
            .onMove { from, to in
                store.moveWorkers(from: from, to: to)
            }

            HStack {
                TextField("Nombre del nuevo trabajador", text: $newWorkerName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addWorker() }

                Button("Añadir") { addWorker() }
                    .disabled(newWorkerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Trabajadores")
        } footer: {
            Text("El orden de la lista determina la rotación de guardias.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var guardSettingsSection: some View {
        Section("Reglas de guardia") {
            Toggle(isOn: Binding(
                get: { store.appData.settings.avoidGuardWeekBeforeVacation },
                set: {
                    var s = store.appData.settings
                    s.avoidGuardWeekBeforeVacation = $0
                    store.updateSettings(s)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evitar guardia la semana previa a vacaciones")
                    Text("Si está activo, la semana anterior a las vacaciones de un trabajador también quedará bloqueada.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var scheduleRangeSection: some View {
        Section("Período de planificación") {
            DatePicker(
                "Fecha de inicio",
                selection: Binding(
                    get: { store.appData.settings.scheduleStartDate },
                    set: {
                        var s = store.appData.settings
                        s.scheduleStartDate = $0
                        store.updateSettings(s)
                    }
                ),
                displayedComponents: .date
            )
            DatePicker(
                "Fecha de fin",
                selection: Binding(
                    get: { store.appData.settings.scheduleEndDate },
                    set: {
                        var s = store.appData.settings
                        s.scheduleEndDate = $0
                        store.updateSettings(s)
                    }
                ),
                in: store.appData.settings.scheduleStartDate...,
                displayedComponents: .date
            )
        }
    }

    private var bizneoSection: some View {
        Section {
            LabeledContent("Instancia") {
                TextField("empresa", text: Binding(
                    get: { store.appData.settings.bizneoInstance },
                    set: {
                        var s = store.appData.settings
                        s.bizneoInstance = $0.trimmingCharacters(in: .whitespaces)
                        store.updateSettings(s)
                    }
                ))
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Token API") {
                SecureField("Token de acceso", text: Binding(
                    get: { store.appData.settings.bizneoToken },
                    set: {
                        var s = store.appData.settings
                        s.bizneoToken = $0.trimmingCharacters(in: .whitespaces)
                        store.updateSettings(s)
                    }
                ))
                .multilineTextAlignment(.trailing)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "cloud.fill")
                Text("Bizneo HR")
            }
        } footer: {
            Text("Introduce la instancia (p.ej. «alzis») y el token de tu cuenta Bizneo. Después vincula cada trabajador a su usuario Bizneo desde Ajustes → Editar trabajador.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var m365Section: some View {
        Section {
            if store.appData.settings.m365IsConnected {
                LabeledContent("Cuenta") {
                    Text(store.appData.settings.m365UserEmail)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Calendario") {
                    Text(store.appData.settings.m365CalendarName)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Conectado")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cambiar…") { showM365Connect = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }
            } else {
                HStack {
                    Text("No conectado")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Configurar…") { showM365Connect = true }
                }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                Text("Microsoft 365")
            }
        } footer: {
            if !store.appData.settings.m365IsConnected {
                Text("Conecta con Microsoft 365 para sincronizar guardias con el calendario configurado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        Section("Acerca de") {
            LabeledContent("Versión", value: "1.0")
            LabeledContent("Copia de seguridad") {
                HStack {
                    Button("Exportar") { exportFromSettings() }
                    Button("Importar") { importFromSettings() }
                }
            }
        }
    }

    // MARK: – Actions

    private func addWorker() {
        let name = newWorkerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addWorker(name: name)
        newWorkerName = ""
    }

    private func exportFromSettings() {
        guard let data = store.exportData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "guardias-backup.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importFromSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK,
           let url = panel.url,
           let data = try? Data(contentsOf: url) {
            _ = store.importData(data)
        }
    }
}

// MARK: – Worker row

struct WorkerRow: View {
    let worker: Worker
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(worker.color)
                .frame(width: 12, height: 12)

            Text(worker.name)

            Spacer()

            Button("Editar", action: onEdit)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.callout)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
}
