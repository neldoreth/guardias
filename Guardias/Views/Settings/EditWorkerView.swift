import SwiftUI

struct EditWorkerView: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let worker: Worker
    @State private var name: String
    @State private var fullName: String
    @State private var colorIndex: Int

    init(worker: Worker) {
        self.worker = worker
        _name = State(initialValue: worker.name)
        _fullName = State(initialValue: worker.fullName)
        _colorIndex = State(initialValue: worker.colorIndex)
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
                        store.updateWorker(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 480)
    }
}
