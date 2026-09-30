import Foundation

// MARK: - Tipos de resultado

struct DayTotal: Identifiable {
    let day: Date          // inicio del día (la noche que terminó ese día + siestas de ese día)
    let hours: Double?     // nil = sin datos
    var id: Date { day }
}

struct NeedInfo {
    let hours: Double          // la que se usa en los cálculos
    let isEstimated: Bool      // true si viene de tus datos
    let estimate: Double?      // estimación con tus datos (aunque no se use)
    let rebounds: Int
    let nightsWithData: Int
}

struct Timing {
    let midSleepHour: Double   // hora del reloj (0–24) a la mitad de tu sueño
    let wakeHour: Double       // hora típica de despertar (0–24)
    let nights: Int            // noches usadas para calcularlo
}

enum WindowKind: String, CaseIterable {
    case modorra, picoManana, bajon, picoTarde, relajacion, melatonina

    var title: String {
        switch self {
        case .modorra: return "Modorra"
        case .picoManana: return "Pico de la mañana"
        case .bajon: return "Bajón de la tarde"
        case .picoTarde: return "Pico de la tarde"
        case .relajacion: return "Relajación"
        case .melatonina: return "Ventana de melatonina"
        }
    }

    var hint: String {
        switch self {
        case .modorra: return "Sal a la luz del sol y muévete para despertar."
        case .picoManana: return "Aprovecha para lo que requiere más concentración."
        case .bajon: return "Buen momento para tareas ligeras o una siesta corta."
        case .picoTarde: return "Segundo impulso del día: ejercicio o trabajo pendiente."
        case .relajacion: return "Baja las luces y deja las pantallas para prepararte a dormir."
        case .melatonina: return "Es el mejor momento para irte a dormir."
        }
    }
}

struct EnergyWindow: Identifiable {
    let kind: WindowKind
    let start: Date
    let end: Date
    var id: String { kind.rawValue }
}

struct EnergyPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct PhaseNow {
    let title: String
    let detail: String
    let kind: WindowKind?
    let until: Date?
}

// MARK: - Modelo SAFTE

enum EnergyModel {
    // Parámetros por defecto publicados de SAFTE.
    static let rc = 2880.0      // capacidad del reservorio (unidades)
    static let k = 0.5          // unidades que se gastan por minuto despierto
    static let a1 = 7.0
    static let a2 = 5.0
    static let beta = 0.5
    static let pPrime = 3.0     // desfase del armónico de 12 h (horas)

    /// Ritmo circadiano: 24 h + armónico de 12 h.
    static func circadian(_ t: Double, p: Double) -> Double {
        cos(2 * Double.pi / 24 * (t - p)) + beta * cos(4 * Double.pi / 24 * (t - p - pPrime))
    }

    static func clockHours(_ date: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    /// Nivel del reservorio al despertar: cada hora de deuda lo baja 1.2 % (máximo 30 %).
    static func startReservoir(debt: Double) -> Double {
        rc * (1 - min(0.30, 0.012 * debt))
    }

    /// Efectividad SAFTE (≈ % de tu rendimiento descansado) en `date`.
    static func effectiveness(at date: Date, wake: Date, wakeClock: Double, debt: Double, p: Double) -> Double {
        let ta = max(0, date.timeIntervalSince(wake) / 3600)           // horas despierto
        let t = wakeClock + ta                                          // hora del reloj (puede pasar de 24)
        let r = max(0, startReservoir(debt: debt) - 60 * k * ta)        // el tanque se vacía 30 unidades/h
        let inertia = min(10, 5 + 0.25 * debt) * exp(-ta / 0.45)        // modorra al despertar
        return 100 * r / rc + (a1 + a2 * (rc - r) / rc) * circadian(t, p: p) - inertia
    }
}

// MARK: - Plan del día

struct DayPlan {
    let wake: Date
    let wakeIsEstimated: Bool
    let wakeClock: Double
    let debt: Double
    let p: Double
    let start: Date
    let end: Date
    let points: [EnergyPoint]       // cada 10 min, para las gráficas
    let windows: [EnergyWindow]     // ordenadas por hora
    let lo: Double
    let hi: Double
    let melatoninStart: Date
    let melatoninEnd: Date

    func value(at date: Date) -> Double {
        EnergyModel.effectiveness(at: date, wake: wake, wakeClock: wakeClock, debt: debt, p: p)
    }

    /// 0 = lo más bajo de tu día, 1 = lo más alto.
    func level(at date: Date) -> Double {
        guard hi - lo > 0.01 else { return 0.5 }
        return min(1, max(0, (value(at: date) - lo) / (hi - lo)))
    }

    func window(_ kind: WindowKind) -> EnergyWindow? {
        windows.first { $0.kind == kind }
    }

    func nextWindow(after date: Date) -> EnergyWindow? {
        windows.filter { $0.start > date }.min { $0.start < $1.start }
    }

    func phase(at date: Date) -> PhaseNow {
        if date < wake {
            return PhaseNow(title: "Aún no despiertas", detail: "", kind: nil, until: wake)
        }
        let priority: [WindowKind] = [.modorra, .melatonina, .relajacion, .picoManana, .bajon, .picoTarde]
        for kind in priority {
            if let w = window(kind), date >= w.start, date < w.end {
                return PhaseNow(title: kind.title, detail: kind.hint, kind: kind, until: w.end)
            }
        }
        if date >= melatoninEnd {
            return PhaseNow(title: "Ya es hora de dormir",
                            detail: "Tu ventana de melatonina ya pasó; entre más tarde, más te va a costar.",
                            kind: nil, until: nil)
        }
        if let next = nextWindow(after: date) {
            return PhaseNow(title: "Energía estable",
                            detail: "Después viene: \(next.kind.title.lowercased()).",
                            kind: nil, until: next.start)
        }
        return PhaseNow(title: "Energía estable", detail: "", kind: nil, until: nil)
    }
}

// MARK: - Resumen

struct SleepSummary {
    let now: Date
    let need: NeedInfo
    let debt: Double
    let last14: [DayTotal]          // de la más vieja a la más reciente
    let nightsWithData14: Int
    let timing: Timing
    let plan: DayPlan
    let potential: Double           // 0–100
    let energyNow: Double           // 0–100
    let phase: PhaseNow
    let targetWake: Date
    let suggestedBedtime: Date
    let plannedSleepHours: Double
    let pendingSleepStart: Date?
    let hasAnyData: Bool

    var isAsleep: Bool { pendingSleepStart != nil }
}

// MARK: - Motor

enum SleepEngine {
    /// Peso de cada noche: [anoche, hace 2 noches, …, hace 14 noches]. Suman 1.
    /// Anoche pesa 15 %; el 85 % restante baja 15 % por cada noche hacia atrás.
    static let weights: [Double] = {
        let rest = (0..<13).map { pow(0.85, Double($0)) }
        let total = rest.reduce(0, +)
        return [0.15] + rest.map { 0.85 * $0 / total }
    }()

    static func summary(data: AppData, now: Date, calendar cal: Calendar = .current) -> SleepSummary {
        let done = data.sessions.filter { $0.end <= now && $0.end > $0.start }
        let byDay = totalsByDay(done, calendar: cal)
        let last14 = lastDays(14, byDay: byDay, now: now, calendar: cal)
        let need = needInfo(settings: data.settings, byDay: byDay, now: now, calendar: cal)
        let debt = sleepDebt(need: need.hours, last14: last14)
        let timing = habitualTiming(done, now: now, settings: data.settings, need: need.hours, calendar: cal)
        let (wake, estimated) = currentWake(done, now: now, timing: timing, calendar: cal)
        let plan = dayPlan(wake: wake, estimated: estimated, debt: debt, timing: timing, need: need.hours, calendar: cal)

        let potential = 100 * exp(-debt / 24)
        let energyNow = potential * (0.75 + 0.25 * plan.level(at: now))

        let target = targetWake(after: wake, settings: data.settings, calendar: cal)
        let extra = min(1.0, debt / 10)                                   // pagar deuda poco a poco
        let raw = target.addingTimeInterval(-(need.hours + extra) * 3600 - 15 * 60)
        let bedtime = max(raw, plan.melatoninStart)                       // no antes de tu ventana
        let planned = max(0, target.timeIntervalSince(bedtime) / 3600 - 0.25)

        return SleepSummary(
            now: now,
            need: need,
            debt: debt,
            last14: last14,
            nightsWithData14: last14.filter { $0.hours != nil }.count,
            timing: timing,
            plan: plan,
            potential: potential,
            energyNow: energyNow,
            phase: plan.phase(at: now),
            targetWake: target,
            suggestedBedtime: bedtime,
            plannedSleepHours: planned,
            pendingSleepStart: data.pendingSleepStart,
            hasAnyData: !data.sessions.isEmpty
        )
    }

    // MARK: Totales por día

    /// Cada registro cuenta para el día en que terminó (la noche de ayer cuenta para hoy).
    static func totalsByDay(_ sessions: [SleepSession], calendar cal: Calendar) -> [Date: Double] {
        var out: [Date: Double] = [:]
        for s in sessions {
            out[cal.startOfDay(for: s.end), default: 0] += s.hours
        }
        return out
    }

    static func lastDays(_ n: Int, byDay: [Date: Double], now: Date, calendar cal: Calendar) -> [DayTotal] {
        let today = cal.startOfDay(for: now)
        return (0..<n).reversed().compactMap { i -> DayTotal? in
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { return nil }
            return DayTotal(day: day, hours: byDay[day])
        }
    }

    // MARK: Deuda

    /// Deuda = Σ 14 · peso · (necesidad − dormido). Las noches sin datos no cuentan. Nunca baja de 0.
    static func sleepDebt(need: Double, last14: [DayTotal]) -> Double {
        var debt = 0.0
        for (k, day) in last14.reversed().enumerated() where k < weights.count {
            guard let hours = day.hours else { continue }
            debt += 14 * weights[k] * (need - hours)
        }
        return max(0, debt)
    }

    // MARK: Necesidad de sueño

    static func needInfo(settings: AppSettings, byDay: [Date: Double], now: Date, calendar cal: Calendar) -> NeedInfo {
        let est = estimateNeed(byDay: byDay, now: now, calendar: cal)
        if settings.autoNeed, let e = est.estimate {
            return NeedInfo(hours: e, isEstimated: true, estimate: e, rebounds: est.rebounds, nightsWithData: est.nights)
        }
        return NeedInfo(hours: settings.manualNeedHours, isEstimated: false, estimate: est.estimate,
                        rebounds: est.rebounds, nightsWithData: est.nights)
    }

    /// Busca "rebotes": días en que dormiste ≥ 1 h más que el promedio de tus 5 registros anteriores,
    /// después de una racha corta. Necesita 21 días con datos y 3 rebotes.
    /// Estimación = promedio + 0.3 · (mediana de rebotes − promedio), entre 5 y 11.5 h.
    static func estimateNeed(byDay: [Date: Double], now: Date, calendar cal: Calendar) -> (estimate: Double?, rebounds: Int, nights: Int) {
        let today = cal.startOfDay(for: now)
        guard let from = cal.date(byAdding: .day, value: -120, to: today) else { return (nil, 0, 0) }
        let days = byDay.keys.filter { $0 >= from && $0 <= today }.sorted()
        let values = days.compactMap { byDay[$0] }
        guard values.count >= 21 else { return (nil, 0, values.count) }

        let avg = values.reduce(0, +) / Double(values.count)
        let med = median(values)
        var rebounds: [Double] = []
        for (k, day) in days.enumerated() {
            guard let total = byDay[day] else { continue }
            let windowStart = cal.date(byAdding: .day, value: -10, to: day) ?? day
            let previous = days[..<k].filter { $0 >= windowStart }.suffix(5).compactMap { byDay[$0] }
            guard previous.count >= 3 else { continue }
            let baseline = previous.reduce(0, +) / Double(previous.count)
            if total - baseline >= 1.0 && baseline <= med + 0.25 {
                rebounds.append(total)
            }
        }
        guard rebounds.count >= 3 else { return (nil, rebounds.count, values.count) }
        let estimate = avg + 0.3 * (median(rebounds) - avg)
        return (min(11.5, max(5.0, estimate)), rebounds.count, values.count)
    }

    // MARK: Horario habitual

    /// Mitad de tu sueño y hora de despertar típicas (promedio circular de hasta 7 noches recientes,
    /// pesando más las más nuevas). Sin datos, se calcula con tu hora de despertar de Ajustes.
    static func habitualTiming(_ sessions: [SleepSession], now: Date, settings: AppSettings, need: Double, calendar cal: Calendar) -> Timing {
        let cutoff = now.addingTimeInterval(-10 * 86400)
        let main = sessions
            .filter { $0.isMainSleep && $0.end <= now && $0.end >= cutoff }
            .sorted { $0.end > $1.end }
            .prefix(7)
        if main.isEmpty {
            let wake = Double(settings.wakeHour) + Double(settings.wakeMinute) / 60
            return Timing(midSleepHour: wrap(wake - need / 2), wakeHour: wake, nights: 0)
        }
        var sinMid = 0.0, cosMid = 0.0, sinWake = 0.0, cosWake = 0.0
        for (i, s) in main.enumerated() {
            let w = pow(0.8, Double(i))
            let mid = s.start.addingTimeInterval(s.end.timeIntervalSince(s.start) / 2)
            let aMid = EnergyModel.clockHours(mid, calendar: cal) / 24 * 2 * Double.pi
            let aWake = EnergyModel.clockHours(s.end, calendar: cal) / 24 * 2 * Double.pi
            sinMid += w * sin(aMid); cosMid += w * cos(aMid)
            sinWake += w * sin(aWake); cosWake += w * cos(aWake)
        }
        let midHour = wrap(atan2(sinMid, cosMid) / (2 * Double.pi) * 24)
        let wakeHour = wrap(atan2(sinWake, cosWake) / (2 * Double.pi) * 24)
        return Timing(midSleepHour: midHour, wakeHour: wakeHour, nights: main.count)
    }

    /// Hora en que empezó tu día: tu último despertar real (si fue hace menos de 20 h) o uno estimado.
    static func currentWake(_ sessions: [SleepSession], now: Date, timing: Timing, calendar cal: Calendar) -> (Date, Bool) {
        if let last = sessions.filter({ $0.isMainSleep && $0.end <= now }).max(by: { $0.end < $1.end }),
           now.timeIntervalSince(last.end) <= 20 * 3600 {
            return (last.end, false)
        }
        var candidate = cal.startOfDay(for: now).addingTimeInterval(timing.wakeHour * 3600)
        if candidate > now { candidate = candidate.addingTimeInterval(-86400) }
        return (candidate, true)
    }

    /// Siguiente hora de despertar (la de Ajustes) después de este día.
    static func targetWake(after wake: Date, settings: AppSettings, calendar cal: Calendar) -> Date {
        let ref = wake.addingTimeInterval(12 * 3600)
        var d = cal.date(bySettingHour: settings.wakeHour, minute: settings.wakeMinute, second: 0, of: ref) ?? ref
        if d <= ref {
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
        }
        return d
    }

    // MARK: Curva y ventanas

    static func dayPlan(wake: Date, estimated: Bool, debt: Double, timing: Timing, need: Double, calendar cal: Calendar) -> DayPlan {
        let wakeClock = EnergyModel.clockHours(wake, calendar: cal)
        let p = wrap(timing.midSleepHour + 15)       // pico del ritmo de 24 h (18:00 si duermes 23:00–7:00)
        let step: TimeInterval = 300                 // un punto cada 5 min
        let perHour = 12
        let count = 18 * perHour + 1                 // 18 horas desde que despiertas

        let fine: [EnergyPoint] = (0..<count).map { i in
            let d = wake.addingTimeInterval(Double(i) * step)
            return EnergyPoint(date: d, value: EnergyModel.effectiveness(at: d, wake: wake, wakeClock: wakeClock, debt: debt, p: p))
        }

        func index(of date: Date) -> Int {
            let i = Int((date.timeIntervalSince(wake) / step).rounded())
            return min(count - 1, max(0, i))
        }
        func argmax(_ a: Int, _ b: Int) -> Int {
            let lo = max(0, min(a, count - 1))
            let hi = max(lo, min(b, count - 1))
            var best = lo
            for i in lo...hi where fine[i].value > fine[best].value { best = i }
            return best
        }
        func argmin(_ a: Int, _ b: Int) -> Int {
            let lo = max(0, min(a, count - 1))
            let hi = max(lo, min(b, count - 1))
            var best = lo
            for i in lo...hi where fine[i].value < fine[best].value { best = i }
            return best
        }
        func grow(_ center: Int, _ a: Int, _ b: Int, _ keep: (Double) -> Bool) -> (Int, Int) {
            var lo = center
            var hi = center
            while lo - 1 >= max(0, a) && keep(fine[lo - 1].value) { lo -= 1 }
            while hi + 1 <= min(count - 1, b) && keep(fine[hi + 1].value) { hi += 1 }
            return (lo, hi)
        }

        // Ventana de melatonina: 1 h alrededor de tu hora "natural" de dormir
        // (mitad de tu sueño − la mitad de tu necesidad).
        var onset = cal.startOfDay(for: wake).addingTimeInterval((timing.midSleepHour - need / 2) * 3600)
        while onset < wake.addingTimeInterval(6 * 3600) { onset = onset.addingTimeInterval(86400) }
        while onset > wake.addingTimeInterval(30 * 3600) { onset = onset.addingTimeInterval(-86400) }
        let melStart = onset.addingTimeInterval(-45 * 60)
        let melEnd = onset.addingTimeInterval(15 * 60)
        let relaxStart = melStart.addingTimeInterval(-3600)

        // Picos y bajón directamente de la curva.
        let groggyEnd = perHour * 3 / 2                                   // 1.5 h de modorra
        let ev = argmax(6 * perHour, 16 * perHour)                        // pico de la tarde
        let dip = argmin(3 * perHour, max(3 * perHour, ev - perHour))     // bajón
        let mp = argmax(groggyEnd, max(groggyEnd, dip))                   // pico de la mañana
        let eDip = fine[dip].value
        let spanM = max(0.01, fine[mp].value - eDip)
        let spanE = max(0.01, fine[ev].value - eDip)
        let spanL = max(0.01, min(fine[mp].value, fine[ev].value) - eDip)

        var windows: [EnergyWindow] = [EnergyWindow(kind: .modorra, start: wake, end: fine[groggyEnd].date)]
        func add(_ kind: WindowKind, _ r: (Int, Int), limit: Date? = nil) {
            let s = fine[r.0].date
            var e = fine[r.1].date
            if let limit = limit, e > limit { e = limit }
            if e.timeIntervalSince(s) >= 20 * 60 {
                windows.append(EnergyWindow(kind: kind, start: s, end: e))
            }
        }
        let morningRange = grow(mp, groggyEnd, dip) { ($0 - eDip) / spanM >= 0.6 }
        let dipRange = grow(dip, mp, ev) { ($0 - eDip) / spanL <= 0.35 }
        let eveningRange = grow(ev, dip, index(of: relaxStart) - 1) { ($0 - eDip) / spanE >= 0.6 }
        add(.picoManana, morningRange)
        add(.bajon, dipRange)
        add(.picoTarde, eveningRange, limit: relaxStart)
        windows.append(EnergyWindow(kind: .relajacion, start: relaxStart, end: melStart))
        windows.append(EnergyWindow(kind: .melatonina, start: melStart, end: melEnd))
        windows.sort { $0.start < $1.start }

        let lastIdx = min(count - 1, index(of: melEnd))
        let waking = fine[0...lastIdx].map { $0.value }
        let lo = waking.min() ?? 80
        let hi = waking.max() ?? 100
        let endDate = min(fine[count - 1].date, max(melEnd.addingTimeInterval(3600), wake.addingTimeInterval(15 * 3600)))
        let points = stride(from: 0, to: count, by: 2).map { fine[$0] }.filter { $0.date <= endDate }

        return DayPlan(wake: wake, wakeIsEstimated: estimated, wakeClock: wakeClock, debt: debt, p: p,
                       start: wake, end: endDate, points: points, windows: windows, lo: lo, hi: hi,
                       melatoninStart: melStart, melatoninEnd: melEnd)
    }

    // MARK: Utilidades

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let s = values.sorted()
        let m = s.count / 2
        return s.count % 2 == 0 ? (s[m - 1] + s[m]) / 2 : s[m]
    }

    static func wrap(_ h: Double) -> Double {
        let r = h.truncatingRemainder(dividingBy: 24)
        return r < 0 ? r + 24 : r
    }
}
