import SwiftUI

struct EditWorkerView: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let worker: Worker
    @State private var name: String
    @State private var fullName: String
    @State private var colorIndex: Int
    @State private var bizneoUserId: Int?
    @State private var bizneoUserName: String
    @State private var showBizneoPicker = false

    init(worker: Worker) {
        self.worker = worker
        _name = State(initialValue: worker.name)
        _fullName = State(initialValue: worker.fullName)
        _colorIndex = State(initialValue: worker.colorIndex)
        _bizneoUserId = State(initialValue: worker.bizneoUserId)
        _bizneoUserName = State(initialValue: worker.bizneoUserName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del trabajador") {
                    LabeledContent("Nombre") {
                        TextField("Nombre corto", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Nombre completo") {
                        TextField("Nombre y apellidos", text: $fullName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Color en el calendario") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(0..<Worker.palette.count, id: \.self) { idx in
                            Button {
                                colorIndex = idx
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Worker.palette[idx])
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if colorIndex == idx {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 3)
                                                    .padding(2)
                                                Image(systemName: "checkmark")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(Worker.paletteNames[idx])
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Vista previa") {
                    HStack {
                        Circle()
                            .fill(Worker.palette[colorIndex])
                            .frame(width: 10, height: 10)
                        Text(name.isEmpty ? "Nombre del trabajador" : name)
                            .foregroundStyle(name.isEmpty ? .tertiary : .primary)
                    }
                    .padding(.vertical, 4)
                }

                bizneoSection
            }
            .formStyle(.grouped)
            .navigationTitle("Editar trabajador")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var updated = worker
                        updated.name = name.trimmingCharacters(in: .whitespaces)
                        updated.fullName = fullName.trimmingCharacters(in: .whitespaces)
                        updated.colorIndex = colorIndex
                        updated.bizneoUserId = bizneoUserId
                        updated.bizneoUserName = bizneoUserName
                        store.updateWorker(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 520)
        .sheet(isPresented: $showBizneoPicker) {
            BizneoUserPickerView(
                instance: store.appData.settings.bizneoInstance,
                token: store.appData.settings.bizneoToken
            ) { user in
                bizneoUserId = user.id
                bizneoUserName = user.fullName
                showBizneoPicker = false
            }
        }
    }

    // MARK: – Bizneo section

    private var bizneoSection: some View {
        Section {
            if let userId = bizneoUserId {
                LabeledContent("Vinculado con") {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text(bizneoUserName.isEmpty ? "ID \(userId)" : bizneoUserName)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Cambiar usuario Bizneo") {
                    guard !store.appData.settings.bizneoInstance.isEmpty else { return }
                    showBizneoPicker = true
                }
                Button("Desvincular de Bizneo", role: .destructive) {
                    bizneoUserId = nil
                    bizneoUserName = ""
                }
            } else {
                HStack {
                    Text("Sin vincular")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Buscar en Bizneo") {
                        showBizneoPicker = true
                    }
                    .disabled(store.appData.settings.bizneoInstance.isEmpty || store.appData.settings.bizneoToken.isEmpty)
                }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "cloud.fill")
                Text("Bizneo HR")
            }
        } footer: {
            if store.appData.settings.bizneoInstance.isEmpty || store.appData.settings.bizneoToken.isEmpty {
                Text("Configura la instancia y el token de Bizneo en los Ajustes generales.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: – Bizneo user picker

struct BizneoUserPickerView: View {
    let instance: String
    let token: String
    let onSelect: (BizneoUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var allUsers: [BizneoUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private var filtered: [BizneoUser] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allUsers }
        return allUsers.filter { $0.fullName.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Cargando usuarios de Bizneo…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { user in
                        Button {
                            onSelect(user)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName)
                                    .fontWeight(.medium)
                                Text("ID: \(user.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $query, prompt: "Buscar por nombre")
                }
            }
            .navigationTitle("Seleccionar usuario Bizneo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 460)
        .task { await loadUsers() }
    }

    private func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            allUsers = try await BizneoService.fetchAllUsers(instance: instance, token: token)
            allUsers.sort { $0.fullName < $1.fullName }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
