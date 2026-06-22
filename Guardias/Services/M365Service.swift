import Foundation

// MARK: – Data types

struct M365Calendar: Identifiable, Hashable {
    let id: String
    let name: String
}

struct M365DeviceCodeInfo {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let message: String
}

enum M365PollResult {
    case pending
    case success(accessToken: String, refreshToken: String, expiresIn: Int)
}

enum M365Error: LocalizedError {
    case authFailed(String)
    case calendarNotFound(String)
    case notConnected
    case noAssignment
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg):        return "Error de autenticación M365: \(msg)"
        case .calendarNotFound(let name): return "No se encontró el calendario «\(name)» en Microsoft 365."
        case .notConnected:               return "No conectado a Microsoft 365. Configúralo en Ajustes."
        case .noAssignment:               return "Esta semana no tiene guardia asignada."
        case .apiError(let code, let msg): return "Error MS Graph (\(code)): \(msg)"
        }
    }
}

// MARK: – Service

enum M365Service {
    private static let graphBase = "https://graph.microsoft.com/v1.0"

    // MARK: Device code flow

    static func startDeviceCodeFlow(clientId: String, tenantId: String) async throws -> M365DeviceCodeInfo {
        guard let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/devicecode") else {
            throw M365Error.authFailed("URL inválida")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(clientId)&scope=Calendars.ReadWrite%20User.Read%20offline_access"
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if let errDesc = json["error_description"] as? String {
            throw M365Error.authFailed(errDesc)
        }
        guard let deviceCode    = json["device_code"]     as? String,
              let userCode      = json["user_code"]        as? String,
              let verificationUri = json["verification_uri"] as? String,
              let message       = json["message"]          as? String else {
            throw M365Error.authFailed("Respuesta de device code inválida")
        }
        return M365DeviceCodeInfo(deviceCode: deviceCode, userCode: userCode,
                                  verificationUri: verificationUri, message: message)
    }

    /// Poll once. Returns .pending while user hasn't authorized yet.
    static func pollDeviceCode(
        deviceCode: String, clientId: String, tenantId: String
    ) async throws -> M365PollResult {
        guard let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token") else {
            throw M365Error.authFailed("URL inválida")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=\(clientId)&device_code=\(deviceCode)"
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if let error = json["error"] as? String {
            switch error {
            case "authorization_pending", "slow_down":
                return .pending
            case "authorization_declined":
                throw M365Error.authFailed("El usuario denegó el acceso.")
            case "expired_token":
                throw M365Error.authFailed("El código ha expirado. Vuelve a intentarlo.")
            default:
                throw M365Error.authFailed(json["error_description"] as? String ?? error)
            }
        }
        guard let accessToken  = json["access_token"]  as? String,
              let refreshToken = json["refresh_token"] as? String,
              let expiresIn    = json["expires_in"]    as? Int else {
            throw M365Error.authFailed("Respuesta de token inválida")
        }
        return .success(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
    }

    // MARK: Token refresh

    static func refreshAccessToken(
        refreshToken: String, clientId: String, tenantId: String
    ) async throws -> (accessToken: String, refreshToken: String, expiresIn: Int) {
        guard let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token") else {
            throw M365Error.authFailed("URL inválida")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)&scope=Calendars.ReadWrite%20User.Read%20offline_access"
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if let errDesc = json["error_description"] as? String {
            throw M365Error.authFailed(errDesc)
        }
        guard let accessToken = json["access_token"] as? String,
              let expiresIn   = json["expires_in"]   as? Int else {
            throw M365Error.authFailed("Respuesta de refresh token inválida")
        }
        let newRefresh = (json["refresh_token"] as? String) ?? refreshToken
        return (accessToken, newRefresh, expiresIn)
    }

    // MARK: Graph API helpers

    static func fetchUserEmail(accessToken: String) async throws -> String {
        let url = URL(string: "\(graphBase)/me?$select=mail,userPrincipalName")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (json["mail"] as? String) ?? (json["userPrincipalName"] as? String) ?? ""
    }

    static func fetchCalendars(accessToken: String) async throws -> [M365Calendar] {
        let url = URL(string: "\(graphBase)/me/calendars?$select=id,name&$top=50")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let errJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let msg = (errJson["error"] as? [String: Any])?["message"] as? String
                      ?? "Error al obtener calendarios (HTTP \(code))"
            throw M365Error.apiError(code, msg)
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let cals = json["value"] as? [[String: Any]] ?? []
        return cals.compactMap { cal in
            guard let id = cal["id"] as? String, let name = cal["name"] as? String else { return nil }
            return M365Calendar(id: id, name: name)
        }
    }

    // MARK: Calendar events

    static func createWeekEvent(
        weekStart: Date, workerName: String, calendarId: String, accessToken: String
    ) async throws -> String {
        let urlStr = "\(graphBase)/me/calendars/\(calendarId)/events"
        guard let url = URL(string: urlStr) else {
            throw M365Error.apiError(0, "URL inválida (calendar ID malformado)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let startStr = fmt.string(from: weekStart)
        let endDate  = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let endStr   = fmt.string(from: endDate)

        let body: [String: Any] = [
            "subject": "Guardia \(workerName)",
            "isAllDay": true,
            "start": ["dateTime": "\(startStr)T00:00:00", "timeZone": "UTC"],
            "end":   ["dateTime": "\(endStr)T00:00:00",   "timeZone": "UTC"],
            "showAs": "free"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 201 else {
            let errJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let msg = (errJson["error"] as? [String: Any])?["message"] as? String
                      ?? "Error al crear el evento (HTTP \(code))"
            throw M365Error.apiError(code, msg)
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard let eventId = json["id"] as? String else {
            throw M365Error.apiError(code, "La respuesta no incluye el ID del evento")
        }
        return eventId
    }

    static func deleteEvent(eventId: String, accessToken: String) async throws {
        let urlStr = "\(graphBase)/me/events/\(eventId)"
        guard let url = URL(string: urlStr) else {
            throw M365Error.apiError(0, "URL inválida (event ID malformado)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 204 else {
            throw M365Error.apiError(code, "Error al eliminar el evento del calendario")
        }
    }
}
