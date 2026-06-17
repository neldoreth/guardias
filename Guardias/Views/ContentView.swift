import SwiftUI

struct ContentView: View {
    @Environment(GuardiasStore.self) private var store
    @State private var selection: SidebarItem? = .calendar
    @State private var showSettings = false

    enum SidebarItem: Hashable {
        case calendar
        case worker(UUID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Calendario") {
                    Label("Todas las guardias", systemImage: "calendar.badge.clock")
                        .tag(SidebarItem.calendar)
                }

                if !store.appData.workers.isEmpty {
                    Section("Vacaciones") {
                        ForEach(store.appData.workers) { worker in
                            Label {
                                Text(worker.name)
                            } icon: {
                                Circle()
                                    .fill(worker.color)
                                    .frame(width: 10, height: 10)
                            }
                            .tag(SidebarItem.worker(worker.id))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Guardias")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Ajustes")
                }
            }
        } detail: {
            switch selection ?? .calendar {
            case .calendar:
                GuardCalendarView()
            case .worker(let id):
                if let worker = store.worker(id: id) {
                    VacationCalendarView(worker: worker)
                } else {
                    GuardCalendarView()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(store)
        }
    }
}
