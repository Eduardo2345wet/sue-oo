import Foundation

// MARK: - Datos de movimiento

/// Actividad que reporta CoreMotion para una muestra. El orden importa: en un empate
/// dentro de un bin gana la primera, así que las de movimiento van antes.
enum MotionKind: String, Codable, CaseIterable {
    case automotive, cycling, running, walking, stationary, unknown

    /// Actividades que significan que estabas despierto y moviéndote.
    var isMoving: Bool {
        switch self {
        case .automotive, .cycling, .running, .walking: return true
        case .stationary, .unknown: return false
        }
    }
}

/// Una muestra de CoreMotion: desde que empezó hasta que llegó la siguiente.
struct MotionSample: Equatable {
    var start: Date
    var end: Date
    var kind: MotionKind
    /// 0 = baja, 1 = media, 2 = alta (igual que CMMotionActivityConfidence).
    var confidence: Int

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Lo que se leyó de los sensores, en bins de 5 min a partir de `start`.
struct MotionInput: Equatable {
    var start: Date
    var binCount: Int
    var samples: [MotionSample]
    /// Pasos por bin (mismo índice que los bins). Si falta un bin, cuenta como 0.
    var steps: [Int]

    var end: Date { SleepDetector.binStart(start, binCount) }
}

// MARK: - Resultado

enum DetectionConfidence: String {
    case alta = "Alta"
    case media = "Media"
    case baja = "Baja"

    /// Según el score promedio del bloque (va de 0.5, el mínimo para proponer, a 1.2).
    init(score: Double) {
        if score >= 0.9 {
            self = .alta
        } else if score >= 0.7 {
            self = .media
        } else {
            self = .baja
        }
    }
}

/// Una noche detectada que todavía no confirmas.
struct SleepProposal: Equatable, Identifiable {
    /// Lo que se muestra: lo detectado más el ajuste aprendido.
    var start: Date
    var end: Date
    /// Lo que salió de los sensores, sin ajuste. Contra esto se miden tus correcciones.
    var raw: DetectedRange
    /// Score promedio del bloque.
    var score: Double

    var id: Date { raw.start }
    var hours: Double { end.timeIntervalSince(start) / 3600 }
    var confidence: DetectionConfidence { DetectionConfidence(score: score) }
}

/// Ajuste aprendido de tus correcciones: la mediana de cuánto moviste inicio y fin.
struct DetectionAdjustment: Equatable {
    var startMinutes: Double
    var endMinutes: Double
    var corrections: Int

    var isActive: Bool { corrections >= SleepDetector.minCorrections }

    static let none = DetectionAdjustment(startMinutes: 0, endMinutes: 0, corrections: 0)
}

/// Un bloque candidato y qué se decidió con él (para Diagnóstico y las pruebas).
struct DetectionBlock {
    let range: DetectedRange
    let score: Double?
    let verdict: String
}

struct DetectionAnalysis {
    let input: MotionInput
    let scores: [Double]       // por bin, ya recortado a [-1, 1.2]
    let smoothed: [Double]     // promedio móvil de 5 bins
    let blocks: [DetectionBlock]
    let proposal: SleepProposal?
}

// MARK: - Detector

/// Estima a qué hora dormiste con la actividad y los pasos del iPhone (sin HealthKit).
///
/// 1. Cada bin de 5 min recibe un score: moverse o caminar lo baja; muestras largas y quietas lo suben;
///    luego se modula con tu horario habitual, sin que la hora pueda crear sueño por sí sola.
/// 2. Promedio móvil de 5 bins, bloques con score ≥ 0.35 uniendo huecos de hasta 25 min.
/// 3. Del bloque más largo al más corto: recorta bordes con score < 0.65 y lo descarta si dura
///    menos de 3 h, si su promedio es < 0.5 o si menos de la mitad cae entre 21:00 y 07:00.
///    También se salta los que ya registraste o descartaste. El primero que pasa es la propuesta.
enum SleepDetector {
    static let binSeconds: TimeInterval = 5 * 60
    static let lookback: TimeInterval = 36 * 3600

    static let enterThreshold = 0.35
    static let edgeThreshold = 0.65
    static let minAverage = 0.5
    static let minHours = 3.0
    static let maxGapBins = 5            // 25 min
    static let smoothingBins = 5
    static let minCorrections = 5
    static let maxCorrections = 60

    // MARK: Bins

    static func binStart(_ start: Date, _ index: Int) -> Date {
        start.addingTimeInterval(Double(index) * binSeconds)
    }

    /// Bins completos de 5 min en las 36 h antes de `now`, alineados al reloj (:00, :05, …).
    static func bins(endingAt now: Date) -> (start: Date, count: Int) {
        let from = now.timeIntervalSinceReferenceDate - lookback
        let start = Date(timeIntervalSinceReferenceDate: (from / binSeconds).rounded(.up) * binSeconds)
        let count = max(0, Int(now.timeIntervalSince(start) / binSeconds))
        return (start, count)
    }

    // MARK: Score por bin

    /// Qué tan probable es que estuvieras dormido en un bin, de -1 a 1.2.
    static func binScore(samples: [MotionSample], steps: Int, binStart: Date,
                         midSleepHour: Double, calendar: Calendar) -> Double {
        let binEnd = binStart.addingTimeInterval(binSeconds)
        var time: [MotionKind: TimeInterval] = [:]
        var confidenceTime: [MotionKind: Double] = [:]
        var longest: TimeInterval = 0
        var count = 0
        for s in samples where s.start < binEnd && s.end > binStart {
            let overlap = min(s.end, binEnd).timeIntervalSince(max(s.start, binStart))
            time[s.kind, default: 0] += overlap
            confidenceTime[s.kind, default: 0] += overlap * Double(s.confidence)
            longest = max(longest, s.duration)
            count += 1
        }
        var dominant: MotionKind? = nil
        var best: TimeInterval = 0
        for kind in MotionKind.allCases {
            if let t = time[kind], t > best {
                best = t
                dominant = kind
            }
        }

        // El movimiento es evidencia directa de que estabas despierto: la hora no lo suaviza.
        if dominant?.isMoving == true || steps >= 8 { return -1 }
        if steps >= 3 { return -0.5 }

        var s = 0.0
        if longest >= 45 * 60 {
            s += 1.0
        } else if longest >= 30 * 60 {
            s += 0.8
        } else if longest >= 15 * 60 {
            s += 0.35
        } else if longest >= 6 * 60 {
            s -= 0.1
        } else {
            s -= 0.6
        }
        if count >= 3 { s -= 0.4 }
        if dominant == .stationary {
            let confidence = (confidenceTime[.stationary] ?? 0) / max(1, time[.stationary] ?? 1)
            s += 0.3 + 0.15 * min(1, confidence / 2)
        } else if dominant == .unknown {
            s += 0.05
        }

        let p = habitPrior(binStart.addingTimeInterval(binSeconds / 2), midSleepHour: midSleepHour, calendar: calendar)
        return min(1.2, max(-1, modulate(s, prior: p)))
    }

    /// Con s ≤ 0 el resultado sigue ≤ 0: el horario solo amplifica o castiga, nunca crea sueño.
    static func modulate(_ s: Double, prior p: Double) -> Double {
        s * (0.5 + 0.9 * p) - 0.25 * (1 - p)
    }

    /// 1 a la mitad de tu sueño habitual, bajando como campana: p = e^(−d²/32), d en horas (±12).
    static func habitPrior(_ date: Date, midSleepHour: Double, calendar: Calendar) -> Double {
        var d = EnergyModel.clockHours(date, calendar: calendar) - midSleepHour
        d -= 24 * (d / 24).rounded()
        return exp(-d * d / 32)
    }

    static func scores(_ input: MotionInput, midSleepHour: Double, calendar: Calendar) -> [Double] {
        (0..<max(0, input.binCount)).map { i in
            binScore(samples: input.samples,
                     steps: i < input.steps.count ? input.steps[i] : 0,
                     binStart: binStart(input.start, i),
                     midSleepHour: midSleepHour,
                     calendar: calendar)
        }
    }

    // MARK: Bloques

    /// Promedio móvil centrado de 5 bins (en las orillas, con los que haya).
    static func smooth(_ values: [Double]) -> [Double] {
        let half = smoothingBins / 2
        return values.indices.map { i in
            let window = values[max(0, i - half)...min(values.count - 1, i + half)]
            return window.reduce(0, +) / Double(window.count)
        }
    }

    /// Tramos con score ≥ 0.35, uniendo los que están separados por huecos de hasta 25 min.
    static func blocks(_ smoothed: [Double]) -> [ClosedRange<Int>] {
        var out: [ClosedRange<Int>] = []
        var i = 0
        while i < smoothed.count {
            guard smoothed[i] >= enterThreshold else {
                i += 1
                continue
            }
            var j = i
            while j + 1 < smoothed.count && smoothed[j + 1] >= enterThreshold { j += 1 }
            if let last = out.last, i - last.upperBound - 1 <= maxGapBins {
                out[out.count - 1] = last.lowerBound...j
            } else {
                out.append(i...j)
            }
            i = j + 1
        }
        return out
    }

    /// Quita bins de las orillas mientras tengan score < 0.65. nil si no queda nada.
    static func trim(_ block: ClosedRange<Int>, _ smoothed: [Double]) -> ClosedRange<Int>? {
        var lo = block.lowerBound
        var hi = block.upperBound
        while lo <= hi && smoothed[lo] < edgeThreshold { lo += 1 }
        while hi >= lo && smoothed[hi] < edgeThreshold { hi -= 1 }
        return lo <= hi ? lo...hi : nil
    }

    static func isNight(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 21 || hour < 7
    }

    // MARK: Análisis completo

    static func analyze(_ input: MotionInput, midSleepHour: Double, sessions: [SleepSession],
                        state: DetectionState, calendar: Calendar = .current) -> DetectionAnalysis {
        let binScores = scores(input, midSleepHour: midSleepHour, calendar: calendar)
        let smoothed = smooth(binScores)
        let learned = adjustment(from: state.corrections)
        let ordered = blocks(smoothed).sorted { a, b in
            a.count != b.count ? a.count > b.count : a.lowerBound > b.lowerBound
        }

        var report: [DetectionBlock] = []
        var proposal: SleepProposal? = nil
        for block in ordered {
            let untrimmed = DetectedRange(start: binStart(input.start, block.lowerBound),
                                          end: binStart(input.start, block.upperBound + 1))
            guard let t = trim(block, smoothed) else {
                report.append(DetectionBlock(range: untrimmed, score: nil, verdict: "Descartado: ningún bin llega a 0.65"))
                continue
            }
            let range = DetectedRange(start: binStart(input.start, t.lowerBound), end: binStart(input.start, t.upperBound + 1))
            let average = smoothed[t].reduce(0, +) / Double(t.count)
            let nightBins = t.filter { isNight(binStart(input.start, $0), calendar: calendar) }.count
            func note(_ verdict: String) {
                report.append(DetectionBlock(range: range, score: average, verdict: verdict))
            }

            if Double(t.count) * binSeconds < minHours * 3600 {
                note("Descartado: dura menos de 3 h")
                continue
            }
            if average < minAverage {
                note("Descartado: score promedio menor a 0.5")
                continue
            }
            if nightBins * 2 < t.count {
                note("Descartado: menos de la mitad cae entre 21:00 y 07:00")
                continue
            }
            let candidate = apply(learned, to: range, score: average, latest: input.end)
            if sessions.contains(where: { $0.start < candidate.end && $0.end > candidate.start }) {
                note("Ya hay un registro que se encima")
                continue
            }
            if state.dismissed.contains(where: { isSame($0, range) }) {
                note("Ya lo descartaste")
                continue
            }
            note("Propuesta")
            proposal = candidate
            break
        }
        return DetectionAnalysis(input: input, scores: binScores, smoothed: smoothed, blocks: report, proposal: proposal)
    }

    /// Dos rangos son "el mismo" si se enciman en al menos 80 % del más largo.
    static func isSame(_ a: DetectedRange, _ b: DetectedRange) -> Bool {
        let overlap = min(a.end, b.end).timeIntervalSince(max(a.start, b.start))
        let longest = max(a.end.timeIntervalSince(a.start), b.end.timeIntervalSince(b.start))
        return longest > 0 && overlap >= 0.8 * longest
    }

    // MARK: Aprendizaje

    /// Mediana de tus correcciones. Solo se aplica con 5 o más.
    static func adjustment(from corrections: [DetectionCorrection]) -> DetectionAdjustment {
        guard !corrections.isEmpty else { return .none }
        return DetectionAdjustment(startMinutes: SleepEngine.median(corrections.map { $0.startMinutes }),
                                   endMinutes: SleepEngine.median(corrections.map { $0.endMinutes }),
                                   corrections: corrections.count)
    }

    /// Lo detectado más el ajuste, redondeado al minuto y sin pasarse de `latest`.
    static func apply(_ adjustment: DetectionAdjustment, to raw: DetectedRange, score: Double, latest: Date) -> SleepProposal {
        var start = raw.start
        var end = raw.end
        if adjustment.isActive {
            let s = roundedToMinute(raw.start.addingTimeInterval(adjustment.startMinutes * 60))
            let e = min(latest, roundedToMinute(raw.end.addingTimeInterval(adjustment.endMinutes * 60)))
            if e.timeIntervalSince(s) >= 3600 {
                start = s
                end = e
            }
        }
        return SleepProposal(start: start, end: end, raw: raw, score: score)
    }

    /// Si cambiaste las horas antes de guardar, guarda la diferencia contra lo detectado (sin ajuste),
    /// así la mediana de las diferencias es directamente el ajuste.
    static func recordCorrection(_ state: inout DetectionState, proposal: SleepProposal,
                                 savedStart: Date, savedEnd: Date, at date: Date) {
        let moved = abs(savedStart.timeIntervalSince(proposal.start)) >= 30
            || abs(savedEnd.timeIntervalSince(proposal.end)) >= 30
        guard moved else { return }
        state.corrections.append(DetectionCorrection(
            date: date,
            startMinutes: (savedStart.timeIntervalSince(proposal.raw.start) / 60).rounded(),
            endMinutes: (savedEnd.timeIntervalSince(proposal.raw.end) / 60).rounded()
        ))
        if state.corrections.count > maxCorrections {
            state.corrections.removeFirst(state.corrections.count - maxCorrections)
        }
    }

    /// Recuerda que descartaste este rango. Los de hace más de 3 días ya no hacen falta.
    static func recordDismissal(_ state: inout DetectionState, proposal: SleepProposal, now: Date) {
        state.dismissed.removeAll { $0.end < now.addingTimeInterval(-3 * 86400) }
        state.dismissed.append(proposal.raw)
    }

    static func roundedToMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded() * 60)
    }
}
