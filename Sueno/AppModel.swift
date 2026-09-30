import Foundation
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data: AppData
    /// Noche detectada con el movimiento del iPhone, esperando que la confirmes.
    @Published private(set) var proposal: SleepProposal? = nil
    /// Último análisis del detector, para Diagnóstico.
    @Published private(set) var detection: DetectionAnalysis? = nil
    private var motionInput: MotionInput? = nil
    private var readingMotion = false
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
        refreshDetection()
    }

    func becameActive() {
        reload()
        Notifier.reschedule(for: data)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await detectSleep() }
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
        refreshDetection()
    }

    // MARK: Detección automática

    /// Lee las últimas 36 h de movimiento y busca una noche sin registrar. Sin permiso o sin datos, no propone nada.
    func detectSleep() async {
        guard !readingMotion else { return }
        readingMotion = true
        motionInput = await MotionReader.read()
        readingMotion = false
        refreshDetection()
    }

    /// Vuelve a correr el detector con lo último que se leyó (rápido; no vuelve a leer los sensores).
    private func refreshDetection() {
        guard let input = motionInput else {
            detection = nil
            proposal = nil
            return
        }
        let analysis = SleepDetector.analyze(input, midSleepHour: summary().timing.midSleepHour,
                                             sessions: data.sessions, state: data.detection)
        detection = analysis
        proposal = data.pendingSleepStart == nil ? analysis.proposal : nil
    }

    /// Guarda la propuesta tal cual o con las horas que editaste (y aprende de la diferencia).
    func acceptProposal(_ proposal: SleepProposal, start: Date? = nil, end: Date? = nil) {
        let s = start ?? proposal.start
        let e = end ?? proposal.end
        guard e > s else { return }
        update { (d: inout AppData) in
            SleepDetector.recordCorrection(&d.detection, proposal: proposal, savedStart: s, savedEnd: e, at: Date())
            let hours = e.timeIntervalSince(s) / 3600
            d.sessions.append(SleepSession(start: s, end: e, isNap: hours < 3, source: .movimiento))
        }
    }

    func dismissProposal(_ proposal: SleepProposal) {
        update { (d: inout AppData) in
            SleepDetector.recordDismissal(&d.detection, proposal: proposal, now: Date())
        }
    }

    func resetDetectionAdjustment() {
        update { (d: inout AppData) in d.detection.corrections = [] }
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
