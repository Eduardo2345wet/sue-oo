import Foundation
import WidgetKit

extension Notification.Name {
    static let suenoDatosCambiaron = Notification.Name("suenoDatosCambiaron")
}

enum SleepActions {
    static func startSleep(_ d: inout AppData, at date: Date) -> String {
        let hadPending = d.pendingSleepStart != nil
        d.pendingSleepStart = date
        return hadPending
            ? "Actualicé tu hora de dormir a las \(Fmt.time(date))."
            : "Listo, a dormir. Registré las \(Fmt.time(date))."
    }

    static func endSleep(_ d: inout AppData, at date: Date) -> String {
        guard let start = d.pendingSleepStart else {
            return "No tenía registrado cuándo te dormiste. Agrégalo en Historial."
        }
        d.pendingSleepStart = nil
        let hours = date.timeIntervalSince(start) / 3600
        guard hours >= 0.25 else { return "Fueron menos de 15 minutos; no lo guardé." }
        guard hours <= 20 else { return "Pasaron más de 20 horas; agrégalo a mano en Historial." }
        let session = SleepSession(start: start, end: date, isNap: hours < 3, source: .boton)
        d.sessions.removeAll { $0.start < session.end && $0.end > session.start }
        d.sessions.append(session)
        return hours < 3
            ? "Siesta de \(Fmt.hm(hours)) guardada."
            : "Dormiste \(Fmt.hm(hours)). Buenos días."
    }

    static func importSleep(_ d: inout AppData, text: String) -> String {
        let imported = SleepImport.sessions(from: text)
        guard !imported.isEmpty else {
            return "No encontré registros válidos. Cada línea debe ser inicio|fin|tipo con fechas ISO 8601."
        }
        var replaced = 0
        for session in imported {
            let before = d.sessions.count
            d.sessions.removeAll { $0.start < session.end && $0.end > session.start }
            replaced += before - d.sessions.count
            d.sessions.append(session)
        }
        let nights = imported.filter { !$0.isNap }.count
        let naps = imported.count - nights
        var message = "Importé \(nights) noche(s)"
        if naps > 0 { message += " y \(naps) siesta(s)" }
        message += "."
        if replaced > 0 { message += " Reemplacé \(replaced) registro(s) que se enciman." }
        return message
    }

    /// Para los Atajos: lee de disco, cambia, guarda, refresca widget y avisos, y avisa a la app si está abierta.
    @MainActor
    static func runStandalone(_ action: (inout AppData) -> String) -> String {
        var data = SharedStore.load()
        let message = action(&data)
        SharedStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        Notifier.reschedule(for: data)
        NotificationCenter.default.post(name: .suenoDatosCambiaron, object: nil)
        return message
    }
}
