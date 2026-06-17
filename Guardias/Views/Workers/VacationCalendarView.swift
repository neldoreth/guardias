import SwiftUI

// MARK: – Main view

struct VacationCalendarView: View {
    @Environment(GuardiasStore.self) private var store
    let worker: Worker
    @State private var selectionStart: Date? = nil   // add-range mode
    @State private var deleteStart: Date? = nil       // delete-range mode
    @State private var showSettings = false

    private var yearStart: Date {
        let year = Calendar.current.component(.year, from: store.appData.settings.scheduleStartDate)
        return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Sticky header (legend + banner) ───────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                VacationLegendCard(worker: worker)

                if let start = selectionStart {
                    SelectionHintBanner(mode: .add, startDate: start) {
                        selectionStart = nil
                    }
                } else if let start = deleteStart {
                    SelectionHintBanner(mode: .delete, startDate: start) {
                        deleteStart = nil
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Scrollable months ─────────────────────────────────────────
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(0..<12, id: \.self) { offset in
                        if let month = Calendar.current.date(
                            byAdding: .month, value: offset, to: yearStart
                        ) {
                            VacationMonthCard(
                                month: month,
                                worker: worker,
                                selectionStart: $selectionStart,
                                deleteStart: $deleteStart
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Vacaciones — \(worker.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .help("Ajustes")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(store)
        }
    }
}

// MARK: – Legend card

struct VacationLegendCard: View {
    let worker: Worker

    var body: some View {
        HStack(spacing: 24) {
            LegendSwatch(fill: .red.opacity(0.18), border: .red.opacity(0.45),
                         text: "Vacaciones", textColor: .red)
            LegendSwatch(fill: worker.color.opacity(0.15), border: worker.color.opacity(0.40),
                         text: "En guardia", textColor: worker.color)
            LegendSwatch(fill: .clear, border: .primary.opacity(0.35),
                         text: "Hoy", textColor: .primary)
            Spacer()
            Text("Clic en día libre: añadir · Clic en vacaciones: eliminar rango · Clic derecho: eliminar día")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

struct LegendSwatch: View {
    let fill: Color
    let border: Color
    let text: String
    let textColor: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(border, lineWidth: 1.5))
                .frame(width: 28, height: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(textColor)
        }
    }
}

// MARK: – Selection hint banner

struct SelectionHintBanner: View {
    enum Mode { case add, delete }
    let mode: Mode
    let startDate: Date
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mode == .add ? "dot.circle" : "minus.circle.fill")
                .foregroundStyle(mode == .add ? Color.blue : Color.red)
            Text(bannerText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancelar selección") { onCancel() }
                .buttonStyle(.bordered)
                .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(mode == .add ? Color.blue.opacity(0.08) : Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    mode == .add ? Color.blue.opacity(0.25) : Color.red.opacity(0.35),
                    lineWidth: 1
                )
        )
    }

    private var bannerText: String {
        switch mode {
        case .add:
            return "Inicio: **\(formattedDate)**  —  Clic en otro día para marcar el rango, o en el mismo para marcar solo ese día."
        case .delete:
            return "Inicio: **\(formattedDate)**  —  Clic en otro día para eliminar el rango de vacaciones, o en el mismo para eliminar solo ese día."
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM"
        return f.string(from: startDate)
    }
}

// MARK: – Month card

struct VacationMonthCard: View {
    @Environment(GuardiasStore.self) private var store
    let month: Date
    let worker: Worker
    @Binding var selectionStart: Date?
    @Binding var deleteStart: Date?

    private let dayLetters = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.bottom, 2)

            HStack(spacing: 0) {
                ForEach(Array(dayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = daysInMonth()
            let offset = firstWeekdayOffset
            let totalCells = offset + days.count
            let rows = Int(ceil(Double(totalCells) / 7.0))

            VStack(spacing: 3) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col - offset
                            if idx >= 0 && idx < days.count {
                                DayCell(
                                    date: days[idx],
                                    worker: worker,
                                    selectionStart: $selectionStart,
                                    deleteStart: $deleteStart
                                )
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: month).capitalized
    }

    private var firstWeekdayOffset: Int {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: month)
        return (weekday - 2 + 7) % 7
    }

    private func daysInMonth() -> [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { day in
            var c = cal.dateComponents([.year, .month], from: month)
            c.day = day
            return cal.date(from: c)
        }
    }
}

// MARK: – Day cell

struct DayCell: View {
    @Environment(GuardiasStore.self) private var store
    let date: Date
    let worker: Worker
    @Binding var selectionStart: Date?
    @Binding var deleteStart: Date?

    private var isVacation: Bool { store.isVacation(date, for: worker) }
    private var isOnGuard: Bool {
        store.assignment(for: date.startOfWeek)?.workerId == worker.id
    }
    private var isPendingStart: Bool { selectionStart?.isSameDay(as: date) == true }
    private var isDeleteStart: Bool { deleteStart?.isSameDay(as: date) == true }
    private var isToday: Bool { date.isToday }

    var body: some View {
        Button(action: handleTap) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.callout)
                .fontWeight(isToday || isPendingStart || isDeleteStart ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isVacation {
                Button(role: .destructive) {
                    store.removeVacationDay(date, for: worker)
                    deleteStart = nil
                } label: {
                    Label("Eliminar este día", systemImage: "trash")
                }
            }
            if isPendingStart {
                Divider()
                Button { selectionStart = nil } label: {
                    Label("Cancelar selección", systemImage: "xmark.circle")
                }
            }
            if isDeleteStart {
                Divider()
                Button { deleteStart = nil } label: {
                    Label("Cancelar eliminación", systemImage: "xmark.circle")
                }
            }
        }
    }

    // MARK: – Tap logic

    private func handleTap() {
        // Complete an ADD range
        if let start = selectionStart {
            if start.isSameDay(as: date) {
                store.addVacationRange(from: date, to: date, for: worker)
            } else {
                store.addVacationRange(from: start, to: date, for: worker)
            }
            selectionStart = nil
            return
        }

        // Complete a DELETE range
        if let start = deleteStart {
            if start.isSameDay(as: date) {
                store.removeVacationRange(from: date, to: date, for: worker)
            } else {
                store.removeVacationRange(from: start, to: date, for: worker)
            }
            deleteStart = nil
            return
        }

        // Start a new selection
        if isVacation {
            deleteStart = date      // vacation day → delete-range mode (red banner)
        } else {
            selectionStart = date   // free day → add-range mode (blue banner)
        }
    }

    // MARK: – Appearance

    private var foregroundColor: Color {
        if isPendingStart { return .white }
        if isDeleteStart { return .red }
        if isVacation { return .red }
        if isOnGuard { return worker.color }
        return .primary
    }

    private var backgroundColor: Color {
        if isPendingStart { return .blue }
        if isDeleteStart { return .red.opacity(0.28) }
        if isVacation { return .red.opacity(0.18) }
        if isOnGuard { return worker.color.opacity(0.15) }
        return .clear
    }

    private var borderColor: Color {
        if isPendingStart { return .blue }
        if isDeleteStart { return .red }
        if isToday { return .primary.opacity(0.35) }
        if isVacation { return .red.opacity(0.35) }
        if isOnGuard { return worker.color.opacity(0.3) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if isPendingStart || isDeleteStart || isToday { return 2 }
        if isVacation || isOnGuard { return 1 }
        return 0
    }
}
