import SwiftUI
import AppKit

// MARK: – View state machine

private enum ConnectState {
    case config
    case awaitingCode(M365DeviceCodeInfo)
    case pickingCalendar(accessToken: String, refreshToken: String, expiresIn: Int, calendars: [M365Calendar])
    case connected
}

struct M365ConnectView: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var clientId = ""
    @State private var tenantId = ""

    @State private var state: ConnectState = .config
    @State private var pollTask: Task<Void, Never>? = nil
    @State private var statusMessage = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                switch state {
                case .connected:
                    connectedSection
                case .awaitingCode(let info):
                    awaitingCodeSection(info)
                case .pickingCalendar(let access, let refresh, let expiresIn, let calendars):
                    calendarPickerSection(
                        accessToken: access, refreshToken: refresh,
                        expiresIn: expiresIn, calendars: calendars
                    )
                case .config:
                    configSection
                }

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Microsoft 365")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 360)
        .onAppear {
            let s = store.appData.settings
            clientId = s.m365ClientId
            tenantId = s.m365TenantId
            if s.m365IsConnected { state = .connected }
        }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: – Connected

    private var connectedSection: some View {
        Section {
            LabeledContent("Cuenta") {
                Text(store.appData.settings.m365UserEmail)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Calendario") {
                Text(store.appData.settings.m365CalendarName)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Estado") {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Conectado").foregroundStyle(.secondary)
                }
            }
            Button("Desconectar", role: .destructive) {
                var s = store.appData.settings
                s.m365AccessToken    = ""
                s.m365RefreshToken   = ""
                s.m365UserEmail      = ""
                s.m365CalendarId     = ""
                s.m365CalendarName   = ""
                s.m365TokenExpiresAt = nil
                store.updateSettings(s)
                state = .config
            }
        } header: { Text("Cuenta Microsoft 365") }
    }

    // MARK: – Awaiting device code authorization

    @ViewBuilder
    private func awaitingCodeSection(_ info: M365DeviceCodeInfo) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Abre el siguiente enlace en tu navegador e introduce el código:")
                    .font(.callout)

                HStack(spacing: 10) {
                    Text(info.userCode)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(info.userCode, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copiar código")
                }

                Button {
                    if let url = URL(string: info.verificationUri) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(info.verificationUri, systemImage: "arrow.up.right.square")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .padding(.vertical, 6)
        } header: { Text("Autorización pendiente") }

        Section {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(statusMessage.isEmpty ? "Esperando autorización en el navegador…" : statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar") {
                    pollTask?.cancel()
                    state = .config
                    statusMessage = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: – Calendar picker

    @ViewBuilder
    private func calendarPickerSection(
        accessToken: String, refreshToken: String, expiresIn: Int, calendars: [M365Calendar]
    ) -> some View {
        Section {
            ForEach(calendars) { calendar in
                Button {
                    Task { await selectCalendar(calendar, accessToken: accessToken,
                                                refreshToken: refreshToken, expiresIn: expiresIn) }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(calendar.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Selecciona un calendario")
        } footer: {
            Text("Elige el calendario de Microsoft 365 donde se sincronizarán las semanas de guardia.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section {
            Button("Cancelar", role: .cancel) {
                state = .config
            }
        }
    }

    // MARK: – Config form

    private var configSection: some View {
        Group {
            Section {
                LabeledContent("Client ID") {
                    TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $clientId)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Tenant ID") {
                    TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $tenantId)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Configuración")
            } footer: {
                Text("Crea una app en portal.azure.com → Azure Active Directory → App registrations. Añade el permiso «Calendars.ReadWrite» (delegado, Microsoft Graph). No necesita URI de redireccionamiento.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Conectar con Microsoft 365") {
                    Task { await startConnection() }
                }
                .disabled(clientId.trimmingCharacters(in: .whitespaces).isEmpty ||
                          tenantId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: – Connection flow

    private func startConnection() async {
        let cId = clientId.trimmingCharacters(in: .whitespaces)
        let tId = tenantId.trimmingCharacters(in: .whitespaces)

        errorMessage = nil

        do {
            let info = try await M365Service.startDeviceCodeFlow(clientId: cId, tenantId: tId)
            state = .awaitingCode(info)

            if let url = URL(string: info.verificationUri) {
                NSWorkspace.shared.open(url)
            }

            pollTask = Task {
                var interval = 5
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                    guard !Task.isCancelled else { break }
                    do {
                        let result = try await M365Service.pollDeviceCode(
                            deviceCode: info.deviceCode, clientId: cId, tenantId: tId
                        )
                        switch result {
                        case .pending:
                            break
                        case .success(let access, let refresh, let expires):
                            await afterAuth(accessToken: access, refreshToken: refresh,
                                            expiresIn: expires, clientId: cId, tenantId: tId)
                            return
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            state = .config
                        }
                        return
                    }
                    interval = min(interval + 1, 15)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func afterAuth(
        accessToken: String, refreshToken: String, expiresIn: Int,
        clientId: String, tenantId: String
    ) async {
        statusMessage = "Autenticado. Obteniendo calendarios…"
        do {
            // Save clientId/tenantId and tokens early (needed for refresh later)
            var s = store.appData.settings
            s.m365ClientId       = clientId
            s.m365TenantId       = tenantId
            s.m365AccessToken    = accessToken
            s.m365RefreshToken   = refreshToken
            s.m365TokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
            store.updateSettings(s)

            let email     = try await M365Service.fetchUserEmail(accessToken: accessToken)
            let calendars = try await M365Service.fetchCalendars(accessToken: accessToken)

            var s2 = store.appData.settings
            s2.m365UserEmail = email
            store.updateSettings(s2)

            statusMessage = ""
            state = .pickingCalendar(
                accessToken: accessToken, refreshToken: refreshToken,
                expiresIn: expiresIn, calendars: calendars
            )
        } catch {
            errorMessage = error.localizedDescription
            state = .config
            statusMessage = ""
        }
    }

    @MainActor
    private func selectCalendar(
        _ calendar: M365Calendar,
        accessToken: String, refreshToken: String, expiresIn: Int
    ) async {
        var s = store.appData.settings
        s.m365CalendarId   = calendar.id
        s.m365CalendarName = calendar.name
        store.updateSettings(s)
        state = .connected
    }
}
