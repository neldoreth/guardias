import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum GuardViewMode: String, CaseIterable {
    case agenda
    case calendario
}

struct GuardCalendarView: View {
    @Environment(GuardiasStore.self) private var store
    @State private var currentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var viewMode: GuardViewMode = .agenda
    @State private var showSettings = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        Group {
            switch viewMode {
            case .agenda:
                AgendaListView(currentYear: currentYear)
            case .calendario:
                CalendarGridView(currentYear: currentYear)
            }
        }
        .navigationTitle("Guardias \(currentYear)")
        .toolbar {
            // ── Left: year navigation ─────────────────────────────────────
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
                    .frame(minWidth: 48)

                Button {
                    currentYear += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Año siguiente")
            }

            // ── Center: view mode picker ──────────────────────────────────
            ToolbarItem(placement: .principal) {
                Picker("", selection: $viewMode) {
                    Image(systemName: "list.bullet").tag(GuardViewMode.agenda)
                    Image(systemName: "calendar").tag(GuardViewMode.calendario)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .help("Cambiar vista")
            }

            // ── Right: settings ───────────────────────────────────────────
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Ajustes (⌘,)")
            }

            // ── Right: backup menu ────────────────────────────────────────
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Exportar copia de seguridad…", systemImage: "arrow.up.doc")
                    }
                    Button {
                        importBackup()
                    } label: {
                        Label("Importar copia de seguridad…", systemImage: "arrow.down.doc")
                    }
                } label: {
                    Image(systemName: "externaldrive")
                }
                .help("Copia de seguridad")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(store)
        }
        .alert("Guardias", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: – Backup

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
                showAlert = true
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
            alertMessage = success
                ? "Copia de seguridad importada correctamente."
                : "El archivo no es válido."
            showAlert = true
        }
    }
}

// MARK: – Agenda subview (current list view)

struct AgendaListView: View {
    @Environment(GuardiasStore.self) private var store
    let currentYear: Int

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
                withAnimation {
                    proxy.scrollTo("\(currentYear)-\(currentMonth)", anchor: .top)
                }
            }
        }
    }
}
