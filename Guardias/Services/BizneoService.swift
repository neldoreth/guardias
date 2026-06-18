import Foundation

struct BizneoUser: Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
}

enum BizneoService {

    // MARK: – Users

    /// Fetches all users from Bizneo concurrently across all pages.
    static func fetchAllUsers(instance: String, token: String) async throws -> [BizneoUser] {
        let (firstUsers, totalPages) = try await fetchUsersPage(1, instance: instance, token: token)
        guard totalPages > 1 else { return firstUsers }

        var allUsers = firstUsers
        try await withThrowingTaskGroup(of: [BizneoUser].self) { group in
            for page in 2...totalPages {
                group.addTask {
                    let (users, _) = try await fetchUsersPage(page, instance: instance, token: token)
                    return users
                }
            }
            for try await users in group {
                allUsers.append(contentsOf: users)
            }
        }
        return allUsers
    }

    // MARK: – Vacations

    /// Fetches all vacation days for a user within the given date range, concurrently across pages.
    static func fetchVacationDays(
        userId: Int, from startDate: Date, to endDate: Date,
        instance: String, token: String
    ) async throws -> [Date] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let startAt = fmt.string(from: startDate)
        let endAt = fmt.string(from: endDate)

        let (firstDays, totalPages) = try await fetchSchedulesPage(
            userId: userId, startAt: startAt, endAt: endAt, page: 1,
            instance: instance, token: token
        )
        guard totalPages > 1 else { return firstDays }

        var allDays = firstDays
        try await withThrowingTaskGroup(of: [Date].self) { group in
            for page in 2...totalPages {
                group.addTask {
                    let (days, _) = try await fetchSchedulesPage(
                        userId: userId, startAt: startAt, endAt: endAt, page: page,
                        instance: instance, token: token
                    )
                    return days
                }
            }
            for try await days in group {
                allDays.append(contentsOf: days)
            }
        }
        return allDays
    }

    // MARK: – Private

    private static func makeURL(
        instance: String, path: String, queryItems: [URLQueryItem]
    ) throws -> URL {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "\(instance).bizneohr.com"
        c.path = path
        c.queryItems = queryItems
        guard let url = c.url else { throw URLError(.badURL) }
        return url
    }

    private static func fetchUsersPage(
        _ page: Int, instance: String, token: String
    ) async throws -> ([BizneoUser], Int) {
        let url = try makeURL(
            instance: instance, path: "/api/v1/users",
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "token", value: token)
            ]
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let usersArr = json["users"] as? [[String: Any]] ?? []
        let pagination = json["pagination"] as? [String: Any] ?? [:]
        let totalPages = pagination["total_pages"] as? Int ?? 1
        let users: [BizneoUser] = usersArr.compactMap { u in
            guard let id = u["id"] as? Int,
                  let first = u["first_name"] as? String,
                  let last = u["last_name"] as? String else { return nil }
            return BizneoUser(id: id, firstName: first, lastName: last)
        }
        return (users, totalPages)
    }

    private static func fetchSchedulesPage(
        userId: Int, startAt: String, endAt: String, page: Int,
        instance: String, token: String
    ) async throws -> ([Date], Int) {
        let url = try makeURL(
            instance: instance,
            path: "/api/v1/users/\(userId)/schedules",
            queryItems: [
                URLQueryItem(name: "start_at", value: startAt),
                URLQueryItem(name: "end_at", value: endAt),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "token", value: token)
            ]
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let dayDetails = json["day_details"] as? [[String: Any]] ?? []
        let pagination = json["pagination"] as? [String: Any] ?? [:]
        let totalPages = pagination["total_pages"] as? Int ?? 1

        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]

        let vacationDays: [Date] = dayDetails.compactMap { day in
            guard let kind = day["kind"] as? String, kind == "absence",
                  let dateStr = day["date"] as? String,
                  let date = isoFmt.date(from: dateStr) else { return nil }
            let absences = day["absences"] as? [[String: Any]] ?? []
            let isVacation = absences.contains { ($0["name"] as? String ?? "").contains("Vacaciones") }
            return isVacation ? date : nil
        }
        return (vacationDays, totalPages)
    }
}
