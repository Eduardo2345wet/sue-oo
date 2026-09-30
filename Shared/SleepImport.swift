import Foundation

/// Convierte el texto que manda el Atajo (una muestra por línea: `inicio|fin|tipo`, fechas ISO 8601)
/// en noches y siestas. Junta las muestras de una misma noche y no cuenta dos veces lo que se encima.
enum SleepImport {
    enum Kind { case asleep, inBed, awake }

    struct Sample {
        let start: Date
        let end: Date
        let kind: Kind
    }

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = isoPlain.date(from: s) { return d }
        if let d = isoFractional.date(from: s) { return d }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            localFormatter.dateFormat = format
            if let d = localFormatter.date(from: s) { return d }
        }
        return nil
    }

    static func classify(_ raw: String) -> Kind {
        let v = raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        if v.contains("cama") || v.contains("inbed") { return .inBed }
        if v.contains("despiert") || v.contains("awake") { return .awake }
        return .asleep
    }

    static func samples(from text: String) -> [Sample] {
        let separators = CharacterSet(charactersIn: "|;\t")
        var out: [Sample] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let parts = line.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2,
                  let start = parseDate(parts[0]),
                  let end = parseDate(parts[1]),
                  end > start,
                  end.timeIntervalSince(start) < 24 * 3600 else { continue }
            let kind: Kind = parts.count >= 3 ? classify(parts[2]) : .asleep
            out.append(Sample(start: start, end: end, kind: kind))
        }
        return out
    }

    /// Une intervalos que se enciman.
    static func union(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var out: [(Date, Date)] = []
        for iv in sorted {
            if let last = out.last, iv.0 <= last.1 {
                out[out.count - 1].1 = max(last.1, iv.1)
            } else {
                out.append(iv)
            }
        }
        return out
    }

    static func sessions(from text: String) -> [SleepSession] {
        let all = samples(from: text).sorted { $0.start < $1.start }
        guard !all.isEmpty else { return [] }

        // Agrupa muestras separadas por menos de 90 min: son la misma noche.
        var clusters: [[Sample]] = []
        var current: [Sample] = []
        var currentEnd = Date.distantPast
        for s in all {
            if current.isEmpty || s.start <= currentEnd.addingTimeInterval(90 * 60) {
                current.append(s)
                currentEnd = max(currentEnd, s.end)
            } else {
                clusters.append(current)
                current = [s]
                currentEnd = s.end
            }
        }
        if !current.isEmpty { clusters.append(current) }

        return clusters.compactMap { cluster -> SleepSession? in
            // Si hay muestras de "dormido" (reloj o app de sueño) se usan esas; si no, "en cama".
            let asleep = cluster.filter { $0.kind == .asleep }
            let chosen = asleep.isEmpty ? cluster.filter { $0.kind == .inBed } : asleep
            guard !chosen.isEmpty else { return nil }
            let merged = union(chosen.map { ($0.start, $0.end) })
            let total = merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
            guard total >= 10 * 60, let first = merged.first, let last = merged.last else { return nil }
            return SleepSession(start: first.0, end: last.1, isNap: total < 3 * 3600, source: .atajo, asleepSeconds: total)
        }
    }
}
