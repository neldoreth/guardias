import SwiftUI
import AppKit

@main
struct GuardiasApp: App {
    @State private var store = GuardiasStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Divider()
                Button("Exportar copia de seguridad…") {
                    exportBackup()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Importar copia de seguridad…") {
                    importBackup()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }

    // MARK: – Backup from menu bar

    @MainActor
    private func exportBackup() {
        guard let data = store.exportData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "guardias-backup.json"
        panel.prompt = "Exportar"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    @MainActor
    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "Importar"
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            _ = store.importData(data)
        }
    }
}
