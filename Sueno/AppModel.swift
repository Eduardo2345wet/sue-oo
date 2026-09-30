import Foundation
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data: AppData
    private var observer: NSObjectProtocol?

    init() {
        data = SharedStore.load()
        // Si un Atajo cambia los datos mientras la app está abierta, se recargan.
        observer = NotificationCenter.default.addObserver(forName: .suenoDatosCambiaron, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func summary(at date: Date = Date()) -> SleepSummary {
        SleepEngine.summary(data: data, now: date)
    }

    func reload() {
        data = SharedStore.load()
    }

    func becameActive() {
        reload()
        Notifier.reschedule(for: data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Cambia los datos, guarda y refresca widget y avisos.
    func update(_ change: (inout AppData) -> Void) {
        var copy = data
        change(&copy)
        guard copy != data else { return }
        commit(copy)
    }

    /// Igual que `update`, pero la acción regresa un mensaje para mostrar.
    @discardableResult
    func perform(_ action: (inout AppData) -> String) -> String {
        var copy = data
        let message = action(&copy)
        commit(copy)
        return message
    }

    private func commit(_ newData: AppData) {
        data = newData
        SharedStore.save(newData)
        WidgetCenter.shared.reloadAllTimelines()
        Notifier.reschedule(for: newData)
    }

    // MARK: Acciones

    @discardableResult
    func startSleep() -> String {
        perform { (d: inout AppData) -> String in SleepActions.startSleep(&d, at: Date()) }
    }

    @discardableResult
    func endSleep() -> String {
        perform { (d: inout AppData) -> String in SleepActions.endSleep(&d, at: Date()) }
    }

    func importText(_ text: String) -> String {
        perform { (d: inout AppData) -> String in SleepActions.importSleep(&d, text: text) }
    }

    func upsert(_ session: SleepSession) {
        update { (d: inout AppData) in
            d.sessions.removeAll { $0.id == session.id }
            d.sessions.append(session)
        }
    }

    func delete(ids: [UUID]) {
        update { (d: inout AppData) in
            d.sessions.removeAll { ids.contains($0.id) }
        }
    }

    func setSettings(_ settings: AppSettings) {
        update { (d: inout AppData) in d.settings = settings }
    }

    func exportData() -> Data {
        SharedStore.encode(data) ?? Data()
    }

    func importBackup(_ raw: Data) -> String {
        guard let decoded = SharedStore.decode(raw) else {
            return "Ese archivo no es un respaldo válido de Sueño."
        }
        update { (d: inout AppData) in d = decoded }
        return "Listo: cargué \(decoded.sessions.count) registros y tus ajustes."
    }

    /// Plantilla para "Nuevo registro": anoche, 8 h antes de tu hora de despertar.
    func newSessionTemplate() -> SleepSession {
        let cal = Calendar.current
        let now = Date()
        let wakeToday = cal.date(bySettingHour: data.settings.wakeHour, minute: data.settings.wakeMinute, second: 0, of: now) ?? now
        let end = min(wakeToday, now)
        return SleepSession(start: wakeToday.addingTimeInterval(-8 * 3600), end: end, source: .manual)
    }
}
