import SwiftUI

enum SidebarItem: Hashable {
    case calendar
    case worker(UUID)
}

struct ContentView: View {
    @Environment(GuardiasStore.self) private var store
    @State private var selection: SidebarItem = .calendar

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
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
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
}
