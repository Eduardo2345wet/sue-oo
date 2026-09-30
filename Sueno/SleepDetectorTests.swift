import Foundation

/// Resultado de una prueba del detector.
struct DetectorTestResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let detail: String
}

/// Pruebas manuales del detector de sueño con días inventados. Se corren desde
/// Ajustes → Diagnóstico → Detección de sueño y no tocan tus datos.
enum SleepDetectorTests {
    static func run() -> [DetectorTestResult] {
        [
            normalNight(),
            noData(),
            habitAloneIsNotSleep(),
            deskDayThenNight(),
            phoneLeftInTheMorning(),
            twoNights(),
            shortNap(),
            upForTenMinutes(),
            stepsBeatStillness(),
            nightDrive(),
            alreadySaved(),
            alreadyDismissed(),
            differentRangeStillShows(),
            gapFilling(),
            edgeTrimming(),
            learnedAdjustment(),
            correctionIsAgainstRaw(),
            confidenceLevels(),
        ]
    }

    // MARK: Casos

    /// Despierto todo el día y dormido de 23:00 a 07:00 con el celular quieto.
    static func normalNight() -> DetectorTestResult {
        let p = DetectorScenario.normal().analyze().proposal
        let ok = p.map { near($0.start, DetectorScenario.at(0, 23)) && near($0.end, DetectorScenario.at(1, 7)) && $0.confidence == .alta } ?? false
        return check("Noche normal de 23:00 a 07:00", ok, describe(p))
    }

    static func noData() -> DetectorTestResult {
        let p = DetectorScenario().analyze().proposal
        return check("Sin datos no propone nada", p == nil, describe(p))
    }

    /// Sin evidencia de sueño, la hora habitual no debe crear un bloque.
    static func habitAloneIsNotSleep() -> DetectorTestResult {
        var worst = -Double.infinity
        for i in 0...150 {
            for j in 0...20 {
                worst = max(worst, SleepDetector.modulate(Double(i - 150) / 100, prior: Double(j) / 20))
            }
        }
        for i in 0..<(24 * 12) {
            let score = SleepDetector.binScore(samples: [], steps: 0, binStart: DetectorScenario.at(0, 0, i * 5),
                                               midSleepHour: 3, calendar: DetectorScenario.calendar)
            worst = max(worst, score)
        }
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(0, 22))
        var t = DetectorScenario.at(0, 22)
        while t < DetectorScenario.at(1, 7) {
            s.add(t, t.addingTimeInterval(10 * 60), .unknown, confidence: 0)
            t = t.addingTimeInterval(10 * 60)
        }
        s.awake(DetectorScenario.at(1, 7), DetectorScenario.now)
        let p = s.analyze().proposal
        return check("El horario solo no crea sueño", worst <= 0 && p == nil,
                     "score máximo sin evidencia: \(fmt(worst)); muestras sueltas de noche: \(describe(p))")
    }

    /// El celular quieto 8.5 h en el escritorio (bloque más largo) no debe tapar la noche real.
    static func deskDayThenNight() -> DetectorTestResult {
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(0, 9))
        s.add(DetectorScenario.at(0, 9), DetectorScenario.at(0, 17, 30), .stationary)
        s.awake(DetectorScenario.at(0, 17, 30), DetectorScenario.at(0, 23, 30))
        s.add(DetectorScenario.at(0, 23, 30), DetectorScenario.at(1, 6, 30), .stationary)
        s.awake(DetectorScenario.at(1, 6, 30), DetectorScenario.now)
        let a = s.analyze()
        let p = a.proposal
        let ok = p.map { near($0.start, DetectorScenario.at(0, 23, 30)) && near($0.end, DetectorScenario.at(1, 6, 30)) } ?? false
        let first = a.blocks.first.map { "primer bloque \(hm($0.range.start))–\(hm($0.range.end)): \($0.verdict)" } ?? "sin bloques"
        return check("Escritorio de día no tapa la noche", ok && a.blocks.count >= 2, "\(first); propuesta: \(describe(p))")
    }

    /// El celular quieto de 7:00 a 15:00 después de una noche en vela: es de día, no es sueño.
    static func phoneLeftInTheMorning() -> DetectorTestResult {
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(0, 7))
        s.add(DetectorScenario.at(0, 7), DetectorScenario.at(0, 15), .stationary)
        s.awake(DetectorScenario.at(0, 15), DetectorScenario.now)
        let a = s.analyze()
        let ok = a.proposal == nil && a.blocks.contains { $0.verdict.contains("21:00") }
        return check("Quieto en la mañana no es una noche", ok,
                     a.blocks.first.map { "\(hm($0.range.start))–\(hm($0.range.end)): \($0.verdict)" } ?? describe(a.proposal))
    }

    /// Dos noches sin registrar: primero la más larga; ya guardada ésa, la otra.
    static func twoNights() -> DetectorTestResult {
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(-1, 23))
        s.add(DetectorScenario.at(-1, 23), DetectorScenario.at(0, 6), .stationary)
        s.awake(DetectorScenario.at(0, 6), DetectorScenario.at(0, 23, 30))
        s.add(DetectorScenario.at(0, 23, 30), DetectorScenario.at(1, 7), .stationary)
        s.awake(DetectorScenario.at(1, 7), DetectorScenario.now)
        let first = s.analyze().proposal
        let saved = first.map { [SleepSession(start: $0.start, end: $0.end, source: .movimiento)] } ?? []
        let second = s.analyze(sessions: saved).proposal
        let ok = (first.map { near($0.start, DetectorScenario.at(0, 23, 30)) } ?? false)
            && (second.map { near($0.start, DetectorScenario.at(-1, 23)) && near($0.end, DetectorScenario.at(0, 6)) } ?? false)
        return check("Dos noches: la más larga y luego la otra", ok, "primero \(describe(first)); después \(describe(second))")
    }

    static func shortNap() -> DetectorTestResult {
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(1, 1))
        s.add(DetectorScenario.at(1, 1), DetectorScenario.at(1, 3), .stationary)
        s.awake(DetectorScenario.at(1, 3), DetectorScenario.now)
        let p = s.analyze().proposal
        return check("Dos horas quieto no es una noche", p == nil, describe(p))
    }

    /// Levantarte 10 min a las 3:00 no debe partir la noche en dos.
    static func upForTenMinutes() -> DetectorTestResult {
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(0, 23))
        s.add(DetectorScenario.at(0, 23), DetectorScenario.at(1, 3), .stationary)
        s.add(DetectorScenario.at(1, 3), DetectorScenario.at(1, 3, 10), .walking)
        s.steps(DetectorScenario.at(1, 3), DetectorScenario.at(1, 3, 10), perBin: 30)
        s.add(DetectorScenario.at(1, 3, 10), DetectorScenario.at(1, 7), .stationary)
        s.awake(DetectorScenario.at(1, 7), DetectorScenario.now)
        let p = s.analyze().proposal
        let ok = p.map { near($0.start, DetectorScenario.at(0, 23)) && near($0.end, DetectorScenario.at(1, 7)) } ?? false
        return check("Levantarte 10 min no parte la noche", ok, describe(p))
    }

    /// Con pasos en el bin, cuenta como despierto aunque CoreMotion diga "quieto".
    static func stepsBeatStillness() -> DetectorTestResult {
        let still = [MotionSample(start: DetectorScenario.at(0, 23), end: DetectorScenario.at(1, 7), kind: .stationary, confidence: 2)]
        let scores = [0, 5, 10].map { steps in
            SleepDetector.binScore(samples: still, steps: steps, binStart: DetectorScenario.at(1, 3),
                                   midSleepHour: 3, calendar: DetectorScenario.calendar)
        }
        return check("Los pasos pesan más que estar quieto", scores == [1.2, -0.5, -1],
                     "0, 5 y 10 pasos: " + scores.map { fmt($0) }.joined(separator: ", "))
    }

    static func nightDrive() -> DetectorTestResult {
        var s = DetectorScenario()
        s.awake(DetectorScenario.at(-1, 20), DetectorScenario.at(0, 22))
        s.add(DetectorScenario.at(0, 22), DetectorScenario.at(1, 4), .automotive)
        s.awake(DetectorScenario.at(1, 4), DetectorScenario.now)
        let p = s.analyze().proposal
        return check("Seis horas en coche no son sueño", p == nil, describe(p))
    }

    static func alreadySaved() -> DetectorTestResult {
        let saved = SleepSession(start: DetectorScenario.at(0, 23, 10), end: DetectorScenario.at(1, 6, 50))
        let a = DetectorScenario.normal().analyze(sessions: [saved])
        let ok = a.proposal == nil && a.blocks.contains { $0.verdict.contains("registro") }
        return check("No propone lo que ya registraste", ok, describe(a.proposal))
    }

    static func alreadyDismissed() -> DetectorTestResult {
        let scenario = DetectorScenario.normal()
        guard let first = scenario.analyze().proposal else {
            return check("No repite una propuesta descartada", false, "la noche normal no dio propuesta")
        }
        var state = DetectionState()
        SleepDetector.recordDismissal(&state, proposal: first, now: DetectorScenario.now)
        let p = scenario.analyze(state: state).proposal
        return check("No repite una propuesta descartada", p == nil, describe(p))
    }

    /// Si a las 3:00 descartaste "23:00 a 03:00", en la mañana sí debe salir la noche completa.
    static func differentRangeStillShows() -> DetectorTestResult {
        var state = DetectionState()
        state.dismissed = [DetectedRange(start: DetectorScenario.at(0, 23), end: DetectorScenario.at(1, 3))]
        let p = DetectorScenario.normal().analyze(state: state).proposal
        let ok = p.map { near($0.end, DetectorScenario.at(1, 7)) } ?? false
        return check("Descartar otro rango no esconde la noche", ok, describe(p))
    }

    static func gapFilling() -> DetectorTestResult {
        let sleep = [Double](repeating: 0.8, count: 10)
        let joined = SleepDetector.blocks(sleep + [Double](repeating: 0, count: 5) + sleep)
        let split = SleepDetector.blocks(sleep + [Double](repeating: 0, count: 6) + sleep)
        let ok = joined == [0...24] && split == [0...9, 16...25]
        return check("Rellena huecos de hasta 25 min", ok,
                     "con hueco de 25 min: \(joined.count) bloque(s); de 30 min: \(split.count) bloque(s)")
    }

    static func edgeTrimming() -> DetectorTestResult {
        let trimmed = SleepDetector.trim(0...5, [0.4, 0.5, 0.7, 0.9, 0.6, 0.4])
        let empty = SleepDetector.trim(0...2, [0.5, 0.6, 0.5])
        let ok = trimmed == 2...3 && empty == nil
        return check("Recorta orillas con score < 0.65", ok, "quedó \(trimmed.map { "\($0)" } ?? "nada"); sin bins altos: \(empty.map { "\($0)" } ?? "nada")")
    }

    static func learnedAdjustment() -> DetectorTestResult {
        let raw = DetectedRange(start: DetectorScenario.at(0, 23), end: DetectorScenario.at(1, 7))
        let starts: [Double] = [10, 20, 15, 30, 5]
        let ends: [Double] = [-10, -5, 0, -20, -15]
        let corrections = zip(starts, ends).map { DetectionCorrection(date: DetectorScenario.now, startMinutes: $0, endMinutes: $1) }
        let four = SleepDetector.apply(SleepDetector.adjustment(from: Array(corrections.prefix(4))), to: raw, score: 1, latest: DetectorScenario.now)
        let five = SleepDetector.apply(SleepDetector.adjustment(from: corrections), to: raw, score: 1, latest: DetectorScenario.now)
        let ok = four.start == raw.start && four.end == raw.end
            && five.start == DetectorScenario.at(0, 23, 15) && five.end == DetectorScenario.at(1, 6, 50)
        return check("Ajuste con la mediana desde 5 correcciones", ok,
                     "con 4: \(hm(four.start))–\(hm(four.end)); con 5: \(hm(five.start))–\(hm(five.end))")
    }

    /// La corrección se mide contra lo detectado, no contra lo que ya traía el ajuste.
    static func correctionIsAgainstRaw() -> DetectorTestResult {
        let proposal = SleepProposal(start: DetectorScenario.at(0, 23, 20), end: DetectorScenario.at(1, 6, 45),
                                     raw: DetectedRange(start: DetectorScenario.at(0, 23, 5), end: DetectorScenario.at(1, 6, 55)), score: 1)
        var state = DetectionState()
        SleepDetector.recordCorrection(&state, proposal: proposal, savedStart: proposal.start, savedEnd: proposal.end, at: DetectorScenario.now)
        let untouched = state.corrections.isEmpty
        SleepDetector.recordCorrection(&state, proposal: proposal, savedStart: DetectorScenario.at(0, 23, 30), savedEnd: proposal.end, at: DetectorScenario.now)
        let c = state.corrections.first
        let ok = untouched && state.corrections.count == 1 && c?.startMinutes == 25 && c?.endMinutes == -10
        return check("Guarda la corrección contra lo detectado", ok,
                     c.map { "inicio \(fmt($0.startMinutes)) min, fin \(fmt($0.endMinutes)) min" } ?? "no guardó nada")
    }

    static func confidenceLevels() -> DetectorTestResult {
        let levels = [1.0, 0.8, 0.6].map { DetectionConfidence(score: $0) }
        return check("Confianza Alta, Media y Baja", levels == [.alta, .media, .baja],
                     levels.map { $0.rawValue }.joined(separator: ", "))
    }

    // MARK: Utilidades

    private static func check(_ name: String, _ passed: Bool, _ detail: String) -> DetectorTestResult {
        DetectorTestResult(name: name, passed: passed, detail: detail)
    }

    /// A 20 min o menos.
    private static func near(_ a: Date, _ b: Date) -> Bool {
        abs(a.timeIntervalSince(b)) <= 20 * 60
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.calendar = DetectorScenario.calendar
        f.timeZone = DetectorScenario.calendar.timeZone
        f.dateFormat = "HH:mm"
        return f
    }()

    static func hm(_ date: Date) -> String {
        clock.string(from: date)
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func describe(_ p: SleepProposal?) -> String {
        guard let p = p else { return "sin propuesta" }
        return "\(hm(p.start))–\(hm(p.end)), score \(fmt(p.score)), confianza \(p.confidence.rawValue.lowercased())"
    }
}

/// Un día y medio inventado: del 9 de marzo a las 20:00 al 11 a las 08:00, hora de Ciudad de México,
/// con la mitad del sueño habitual a las 3:00.
struct DetectorScenario {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .current
        return c
    }()
    static let base: Date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10)) ?? Date()
    static let now = at(1, 8)

    /// Día 0 = 10 de marzo, -1 = el 9, 1 = el 11.
    static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        base.addingTimeInterval(Double(day) * 86400 + Double(hour) * 3600 + Double(minute) * 60)
    }

    var samples: [MotionSample] = []
    var stepRanges: [(from: Date, to: Date, perBin: Int)] = []

    mutating func add(_ from: Date, _ to: Date, _ kind: MotionKind, confidence: Int = 2) {
        samples.append(MotionSample(start: from, end: to, kind: kind, confidence: confidence))
    }

    mutating func steps(_ from: Date, _ to: Date, perBin: Int) {
        stepRanges.append((from, to, perBin))
    }

    /// Despierto: 8 min quieto y 4 caminando (con pasos), una y otra vez.
    mutating func awake(_ from: Date, _ to: Date) {
        var t = from
        while t < to {
            let still = min(to, t.addingTimeInterval(8 * 60))
            add(t, still, .stationary, confidence: 1)
            let walk = min(to, still.addingTimeInterval(4 * 60))
            if walk > still {
                add(still, walk, .walking)
                steps(still, walk, perBin: 40)
            }
            t = walk
        }
    }

    func input() -> MotionInput {
        let (start, count) = SleepDetector.bins(endingAt: DetectorScenario.now)
        var bins = [Int](repeating: 0, count: count)
        for r in stepRanges {
            for i in 0..<count {
                let b = SleepDetector.binStart(start, i)
                if b < r.to && b.addingTimeInterval(SleepDetector.binSeconds) > r.from {
                    bins[i] += r.perBin
                }
            }
        }
        return MotionInput(start: start, binCount: count, samples: samples.sorted { $0.start < $1.start }, steps: bins)
    }

    func analyze(sessions: [SleepSession] = [], state: DetectionState = DetectionState()) -> DetectionAnalysis {
        SleepDetector.analyze(input(), midSleepHour: 3, sessions: sessions, state: state, calendar: DetectorScenario.calendar)
    }

    /// Despierto hasta las 23:00, dormido hasta las 07:00 (con una muestra corta a las 2:10) y despierto después.
    static func normal() -> DetectorScenario {
        var s = DetectorScenario()
        s.awake(at(-1, 20), at(0, 23))
        s.add(at(0, 23), at(1, 2, 10), .stationary)
        s.add(at(1, 2, 10), at(1, 2, 14), .unknown, confidence: 0)
        s.add(at(1, 2, 14), at(1, 7), .stationary)
        s.awake(at(1, 7), now)
        return s
    }
}
