import SwiftUI

struct Worker: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var fullName: String = ""
    var colorIndex: Int
    var bizneoUserId: Int? = nil
    var bizneoUserName: String = ""

    init(id: UUID = UUID(), name: String, fullName: String = "", colorIndex: Int = 0,
         bizneoUserId: Int? = nil, bizneoUserName: String = "") {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.colorIndex = colorIndex
        self.bizneoUserId = bizneoUserId
        self.bizneoUserName = bizneoUserName
    }

    // MARK: – Color palette

    static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint
    ]

    static let paletteNames: [String] = [
        "Azul", "Verde", "Naranja", "Morado", "Rosa", "Teal", "Índigo", "Menta"
    ]

    var color: Color {
        Worker.palette[colorIndex % Worker.palette.count]
    }
}
