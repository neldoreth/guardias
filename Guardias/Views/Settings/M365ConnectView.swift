import SwiftUI
import AppKit

struct M365ConnectView: View {
    @Environment(GuardiasStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var clientId = ""
    @State private var tenantId = ""
    @State private var calendarName = "Guardias ClickEZ"

    @State private var isConnecting = false
    @State private var deviceCodeInfo: M365DeviceCodeInfo? = nil
    @State private var pollTask: Task<Void, Never>? = nil
    @State private var errorMessage: String? = nil
    @State private var statusMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if store.appData.settings.m365IsConnected {
                    connectedSection
                } else if isConnecting, let info = deviceCodeInfo {
                    connectingSection(info)
                } else {
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
            calendarName = s.m365CalendarName.isEmpty ? "Guardias ClickEZ" : s.m365CalendarName
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
                    Text("Conectado")
                        .foregroundStyle(.secondary)
                }
            }
            Button("Desconectar", role: .destructive) {
                var s = store.appData.settings
                s.m365AccessToken = ""
                s.m365RefreshToken = ""
                s.m365UserEmail = ""
                s.m365CalendarId = ""
                s.m365TokenExpiresAt = nil
                store.updateSettings(s)
            }
        } header: {
            Text("Cuenta Microsoft 365")
        }
    }

    // MARK: – Connecting (device code)

    @ViewBuilder
    private func connectingSection(_ info: M365DeviceCodeInfo) -> some View {
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
        } header: {
            Text("Autorización pendiente")
        }

        Section {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(statusMessage.isEmpty ? "Esperando autorización en el navegador…" : statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar") {
                    pollTask?.cancel()
                    isConnecting = false
                    deviceCodeInfo = nil
                    statusMessage = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: – Not connected (config form)

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
                LabeledContent("Calendario") {
                    TextField("Guardias ClickEZ", text: $calendarName)
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
        let calName = calendarName.trimmingCharacters(in: .whitespaces).isEmpty
                      ? "Guardias ClickEZ"
                      : calendarName.trimmingCharacters(in: .whitespaces)

        errorMessage = nil
        isConnecting = true

        do {
            let info = try await M365Service.startDeviceCodeFlow(clientId: cId, tenantId: tId)
            deviceCodeInfo = info

            // Open browser automatically
            if let url = URL(string: info.verificationUri) {
                NSWorkspace.shared.open(url)
            }

            // Poll until authorized or cancelled
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
                        case .success(let access, let refresh, let expiresIn):
                            await finishConnection(
                                accessToken: access, refreshToken: refresh,
                                expiresIn: expiresIn, clientId: cId, tenantId: tId,
                                calendarName: calName
                            )
                            return
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            isConnecting = false
                            deviceCodeInfo = nil
                        }
                        return
                    }
                    interval = min(interval + 1, 15) // slow down over time
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isConnecting = false
        }
    }

    @MainActor
    private func finishConnection(
        accessToken: String, refreshToken: String, expiresIn: Int,
        clientId: String, tenantId: String, calendarName: String
    ) async {
        statusMessage = "Autenticado. Buscando calendario…"
        do {
            let email  = try await M365Service.fetchUserEmail(accessToken: accessToken)
            let calId  = try await M365Service.findCalendarId(named: calendarName, accessToken: accessToken)

            var s = store.appData.settings
            s.m365ClientId       = clientId
            s.m365TenantId       = tenantId
            s.m365CalendarName   = calendarName
            s.m365AccessToken    = accessToken
            s.m365RefreshToken   = refreshToken
            s.m365TokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
            s.m365UserEmail      = email
            s.m365CalendarId     = calId
            store.updateSettings(s)

            isConnecting = false
            deviceCodeInfo = nil
            statusMessage = ""
        } catch {
            errorMessage = error.localizedDescription
            isConnecting = false
            deviceCodeInfo = nil
            statusMessage = ""
        }
    }
}
