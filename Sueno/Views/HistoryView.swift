import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @State var editing: SleepSession? = nil
    @State var adding: SleepSession? = nil

    var body: some View {
        let summary = model.summary()
        let sessions = model.data.sessions.sorted { $0.end > $1.end }

        NavigationStack {
            List {
                Section {
                    NightsChart(days: summary.last14, need: summary.need.hours)
                        .frame(height: 190)
                        .padding(.vertical, 8)
                        .listRowBackground(Theme.tarjeta)
                } footer: {
                    Text("Últimas 14 noches contra tu necesidad de \(Fmt.hm(summary.need.hours)). Deuda actual: \(Fmt.debt(summary.debt)).")
                }

                Section {
                    if sessions.isEmpty {
                        Text("Sin registros todavía. Toca + para agregar tu última noche.")
                            .foregroundStyle(Theme.tintaSuave)
                            .listRowBackground(Theme.tarjeta)
                    }
                    ForEach(sessions) { session in
                        Button {
                            editing = session
                        } label: {
                            SessionRow(session: session)
                        }
                        .listRowBackground(Theme.tarjeta)
                    }
                    .onDelete { offsets in
                        model.delete(ids: offsets.map { sessions[$0].id })
                    }
                } header: {
                    Text("Registros")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adding = model.newSessionTemplate()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Agregar registro")
                }
            }
            .sheet(item: $editing) { session in
                SessionEditorView(session: session, original: session, isNew: false)
                    .environmentObject(model)
            }
            .sheet(item: $adding) { session in
                SessionEditorView(session: session, original: session, isNew: true)
                    .environmentObject(model)
            }
        }
    }
}

struct NightsChart: View {
    let days: [DayTotal]
    let need: Double

    var body: some View {
        let top = max(12.0, (days.compactMap { $0.hours }.max() ?? 0) + 1)
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Día", day.day, unit: .day),
                    y: .value("Horas", day.hours ?? 0)
                )
                .foregroundStyle((day.hours ?? 0) >= need ? Theme.bien : Theme.marea)
                .cornerRadius(3)
            }
            RuleMark(y: .value("Necesidad", need))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Theme.ambar)
        }
        .chartYScale(domain: 0...top)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.day())
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 4.0, 8.0, 12.0]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.tintaSuave.opacity(0.25))
                AxisValueLabel()
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
    }
}

struct SessionRow: View {
    let session: SleepSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.day(session.end))
                    .foregroundStyle(Theme.tinta)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.tintaSuave)
            }
            Spacer()
            Text(Fmt.hm(session.hours))
                .font(Theme.display(18))
                .monospacedDigit()
                .foregroundStyle(Theme.tinta)
        }
    }

    var subtitle: String {
        var text = Fmt.range(session.start, session.end)
        if session.isNap { text += ", siesta" }
        switch session.source {
        case .atajo: text += ", de Salud"
        case .boton: text += ", con el botón"
        case .movimiento: text += ", detectado por movimiento"
        case .manual: break
        }
        return text
    }
}

struct SessionEditorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State var session: SleepSession
    let original: SleepSession
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Me dormí", selection: $session.start)
                    DatePicker("Me desperté", selection: $session.end, in: session.start...)
                    Toggle("Fue una siesta", isOn: $session.isNap)
                } footer: {
                    Text(footer)
                }
                if !isNew {
                    Section {
                        Button("Borrar registro", role: .destructive) {
                            model.delete(ids: [session.id])
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Nuevo registro" : "Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(session.end <= session.start)
                }
            }
        }
    }

    var footer: String {
        var text = "Duración: \(Fmt.hm(session.spanHours))."
        if let asleep = session.asleepSeconds, session.start == original.start, session.end == original.end {
            text += " Dormido según Salud: \(Fmt.hm(asleep / 3600))."
        }
        return text
    }

    func save() {
        var s = session
        if s.start != original.start || s.end != original.end {
            // Si cambias las horas, lo de Salud ya no aplica.
            s.asleepSeconds = nil
            if s.source == .atajo { s.source = .manual }
        }
        model.upsert(s)
        dismiss()
    }
}
