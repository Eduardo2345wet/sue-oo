import SwiftUI
import Charts

extension DetectionConfidence {
    var color: Color {
        switch self {
        case .alta: return Theme.bien
        case .media: return Theme.ambar
        case .baja: return Theme.alerta
        }
    }
}

/// Noche detectada con el movimiento del iPhone. Nunca se guarda sin que la confirmes.
struct DetectionCard: View {
    @EnvironmentObject var model: AppModel
    let proposal: SleepProposal
    @State var editing: SleepProposal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Detección automática", systemImage: "bed.double.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.melatonina)
            Text("Parece que dormiste de \(Fmt.time(proposal.start)) a \(Fmt.time(proposal.end)) (\(Fmt.hm(proposal.hours)))")
                .font(Theme.display(20))
                .foregroundStyle(Theme.tinta)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("\(Fmt.day(proposal.end)) · Confianza:")
                    .foregroundStyle(Theme.tintaSuave)
                Text(proposal.confidence.rawValue)
                    .foregroundStyle(proposal.confidence.color)
            }
            .font(.footnote)
            HStack(spacing: 10) {
                Button("Guardar") { model.acceptProposal(proposal) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.melatonina)
                    .foregroundStyle(Theme.nocheHonda)
                Button("Editar") { editing = proposal }
                    .buttonStyle(.bordered)
                    .tint(Theme.tinta)
                Button("Descartar", role: .destructive) { model.dismissProposal(proposal) }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.nocheHonda, in: RoundedRectangle(cornerRadius: 16))
        .sheet(item: $editing) { p in
            ProposalEditorView(proposal: p, start: p.start, end: p.end)
                .environmentObject(model)
        }
    }
}

struct ProposalEditorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let proposal: SleepProposal
    @State var start: Date
    @State var end: Date

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Me dormí", selection: $start)
                    DatePicker("Me desperté", selection: $end, in: start...)
                } footer: {
                    Text("Duración: \(Fmt.hm(end.timeIntervalSince(start) / 3600)). El sensor detectó \(Fmt.range(proposal.raw.start, proposal.raw.end)); si cambias las horas, la app aprende de la diferencia.")
                }
            }
            .navigationTitle("Editar propuesta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        model.acceptProposal(proposal, start: start, end: end)
                        dismiss()
                    }
                    .disabled(end <= start)
                }
            }
        }
    }
}

/// Ajustes → Diagnóstico → Detección de sueño: sensor, lo que vio en 36 h, ajuste aprendido y pruebas.
struct DetectionDiagnosticsView: View {
    @EnvironmentObject var model: AppModel
    @State var results: [DetectorTestResult] = []
    @State var confirmReset = false
    @State var reading = false

    var body: some View {
        let adjustment = SleepDetector.adjustment(from: model.data.detection.corrections)

        Form {
            Section {
                LabeledContent("Permiso de movimiento", value: MotionReader.access.label)
                if let analysis = model.detection {
                    LabeledContent("Muestras de actividad", value: "\(analysis.input.samples.count)")
                    LabeledContent("Pasos en 36 h", value: "\(analysis.input.steps.reduce(0, +))")
                } else {
                    Text("Sin datos de movimiento.")
                        .foregroundStyle(Theme.tintaSuave)
                }
                Button(reading ? "Leyendo…" : "Volver a leer el sensor") {
                    reading = true
                    Task {
                        await model.detectSleep()
                        reading = false
                    }
                }
                .disabled(reading)
            } header: {
                Text("Sensor")
            } footer: {
                Text(MotionReader.access == .denied
                     ? "Actívalo en Ajustes del iPhone → Privacidad y seguridad → Movimiento y forma física."
                     : "Se leen las últimas 36 h cada vez que abres la app. Nada sale de tu iPhone.")
            }

            if let analysis = model.detection {
                Section {
                    DetectionScoreChart(analysis: analysis)
                        .frame(height: 160)
                        .padding(.vertical, 6)
                    if analysis.blocks.isEmpty {
                        Text("Ningún tramo llegó a 0.35.")
                            .foregroundStyle(Theme.tintaSuave)
                    }
                    ForEach(Array(analysis.blocks.enumerated()), id: \.offset) { _, block in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Fmt.day(block.range.end)), \(Fmt.range(block.range.start, block.range.end))")
                            Text(block.score.map { "\(block.verdict) · score \(String(format: "%.2f", $0))" } ?? block.verdict)
                                .font(.footnote)
                                .foregroundStyle(Theme.tintaSuave)
                        }
                    }
                } header: {
                    Text("Últimas 36 h")
                } footer: {
                    Text("Score por bin de 5 min, ya suavizado. Desde 0.35 cuenta como posible sueño y las orillas se recortan hasta 0.65. La franja morada es la propuesta.")
                }
            }

            Section {
                LabeledContent("Correcciones", value: "\(adjustment.corrections)")
                if adjustment.corrections > 0 {
                    LabeledContent("Inicio", value: Fmt.signedMinutes(adjustment.startMinutes))
                    LabeledContent("Fin", value: Fmt.signedMinutes(adjustment.endMinutes))
                }
                Button("Reiniciar ajuste", role: .destructive) { confirmReset = true }
                    .disabled(adjustment.corrections == 0)
            } header: {
                Text("Ajuste aprendido")
            } footer: {
                Text(adjustment.isActive
                     ? "Se suma a las propuestas nuevas: la mediana de cuánto moviste el inicio y el fin al editar."
                     : "Cuando editas una propuesta antes de guardarla, se anota cuánto moviste el inicio y el fin. Con 5 correcciones se empieza a aplicar la mediana (llevas \(adjustment.corrections)).")
            }

            Section {
                Button("Correr pruebas") { results = SleepDetectorTests.run() }
                if !results.isEmpty {
                    let passed = results.filter { $0.passed }.count
                    Text("\(passed) de \(results.count) pasaron")
                        .foregroundStyle(passed == results.count ? Theme.bien : Theme.alerta)
                }
                ForEach(results) { result in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(result.passed ? Theme.bien : Theme.alerta)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                            Text(result.detail)
                                .font(.footnote)
                                .foregroundStyle(Theme.tintaSuave)
                        }
                    }
                }
            } header: {
                Text("Pruebas del detector")
            } footer: {
                Text("Días inventados con resultado conocido. No tocan tus registros.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.noche.ignoresSafeArea())
        .navigationTitle("Detección de sueño")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Reiniciar el ajuste aprendido?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reiniciar", role: .destructive) { model.resetDetectionAdjustment() }
        } message: {
            Text("Se borran tus correcciones y las propuestas vuelven a salir tal como las detecta el sensor.")
        }
    }
}

/// Score suavizado de las últimas 36 h, con la línea de 0.35 y la propuesta sombreada.
struct DetectionScoreChart: View {
    let analysis: DetectionAnalysis

    var body: some View {
        let points = analysis.smoothed.enumerated().map { i, value in
            EnergyPoint(date: SleepDetector.binStart(analysis.input.start, i), value: value)
        }

        Chart {
            if let p = analysis.proposal {
                RectangleMark(
                    xStart: .value("Inicio", p.raw.start),
                    xEnd: .value("Fin", p.raw.end),
                    yStart: .value("Base", -1.0),
                    yEnd: .value("Tope", 1.2)
                )
                .foregroundStyle(Theme.melatonina.opacity(0.2))
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Hora", point.date),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(Theme.ambar)
            }
            RuleMark(y: .value("Umbral", SleepDetector.enterThreshold))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Theme.tintaSuave)
        }
        .chartYScale(domain: -1.0...1.2)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.tintaSuave.opacity(0.25))
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
        .chartYAxis {
            AxisMarks(values: [-1.0, 0.0, 1.0]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.tintaSuave.opacity(0.25))
                AxisValueLabel()
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
    }
}
