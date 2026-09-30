import Foundation

/// De dónde salió un registro de sueño.
enum SleepSource: String, Codable {
    case manual
    case boton
    case atajo
}

/// Un bloque de sueño: una noche o una siesta.
struct SleepSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var start: Date
    var end: Date
    var isNap: Bool = false
    var source: SleepSource = .manual
    /// Segundos realmente dormido (si lo sabemos, por ejemplo al importar de Salud).
    var asleepSeconds: Double? = nil

    /// Horas dormidas: lo que dijo Salud si lo sabemos; si no, de inicio a fin.
    var hours: Double { (asleepSeconds ?? end.timeIntervalSince(start)) / 3600 }

    /// Horas entre inicio y fin.
    var spanHours: Double { end.timeIntervalSince(start) / 3600 }

    /// Sueño principal: no es siesta y dura al menos 3 horas.
    var isMainSleep: Bool { !isNap && spanHours >= 3 }
}

struct AppSettings: Codable, Equatable {
    var manualNeedHours: Double = 8.25
    var autoNeed: Bool = true
    var wakeHour: Int = 7
    var wakeMinute: Int = 0
    var notifyMelatonin: Bool = true
    var notifyBedtime: Bool = true
}

struct AppData: Codable, Equatable {
    var sessions: [SleepSession] = []
    var settings: AppSettings = AppSettings()
    /// Hora en que tocaste "Me voy a dormir" y todavía no "Ya me desperté".
    var pendingSleepStart: Date? = nil
}

// Decodificación tolerante: si en el futuro se agregan campos, los respaldos viejos siguen sirviendo.

extension SleepSession {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decode(Date.self, forKey: .end)
        isNap = (try? c.decodeIfPresent(Bool.self, forKey: .isNap)) ?? false
        source = (try? c.decodeIfPresent(SleepSource.self, forKey: .source)) ?? .manual
        asleepSeconds = try? c.decodeIfPresent(Double.self, forKey: .asleepSeconds)
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        manualNeedHours = (try? c.decodeIfPresent(Double.self, forKey: .manualNeedHours)) ?? d.manualNeedHours
        autoNeed = (try? c.decodeIfPresent(Bool.self, forKey: .autoNeed)) ?? d.autoNeed
        wakeHour = (try? c.decodeIfPresent(Int.self, forKey: .wakeHour)) ?? d.wakeHour
        wakeMinute = (try? c.decodeIfPresent(Int.self, forKey: .wakeMinute)) ?? d.wakeMinute
        notifyMelatonin = (try? c.decodeIfPresent(Bool.self, forKey: .notifyMelatonin)) ?? d.notifyMelatonin
        notifyBedtime = (try? c.decodeIfPresent(Bool.self, forKey: .notifyBedtime)) ?? d.notifyBedtime
    }
}

extension AppData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessions = (try? c.decodeIfPresent([SleepSession].self, forKey: .sessions)) ?? []
        settings = (try? c.decodeIfPresent(AppSettings.self, forKey: .settings)) ?? AppSettings()
        pendingSleepStart = try? c.decodeIfPresent(Date.self, forKey: .pendingSleepStart)
    }
}
