import SwiftUI

struct Worker: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
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
