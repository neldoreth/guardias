import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct GuardCalendarView: View {
    @Environment(GuardiasStore.self) private var store
    @State private var currentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showExportAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28, pinnedViews: .sectionHeaders) {
                    ForEach(1...12, id: \.self) { month in
                        MonthSectionView(month: month, year: currentYear)
                            .id("\(currentYear)-\(month)")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .onAppear {
                let currentMonth = Calendar.current.component(.month, from: Date())
                proxy.scrollTo("\(currentYear)-\(currentMonth)", anchor: .top)
            }
        }
        .navigationTitle("Guardias \(currentYear)")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    currentYear -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Año anterior")

                Text(String(currentYear))
                    .font(.headline)
                    .monospacedDigit()

                Button {
                    currentYear += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Año siguiente")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: exportBackup) {
                    Label("Exportar", systemImage: "arrow.up.doc")
                }
                .help("Exportar copia de seguridad (⌘⇧E)")

                Button(action: importBackup) {
                    Label("Importar", systemImage: "arrow.down.doc")
                }
                .help("Importar copia de seguridad (⌘⇧I)")
            }
        }
        .alert("Importación", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: – Backup actions

    private func exportBackup() {
        guard let data = store.exportData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "guardias-backup-\(currentYear).json"
        panel.prompt = "Exportar"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                alertMessage = "Error al exportar: \(error.localizedDescription)"
                showExportAlert = true
            }
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "Importar"
        if panel.runModal() == .OK,
           let url = panel.url,
           let data = try? Data(contentsOf: url) {
            let success = store.importData(data)
            alertMessage = success ? "Copia de seguridad importada correctamente." : "El archivo no es válido."
            showExportAlert = true
        }
    }
}
