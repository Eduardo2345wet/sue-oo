import Foundation
import CoreMotion

/// Permiso de Movimiento y forma física.
enum MotionAccess {
    case allowed, notAsked, denied, unavailable

    var label: String {
        switch self {
        case .allowed: return "Permitido"
        case .notAsked: return "Sin pedir"
        case .denied: return "Negado"
        case .unavailable: return "No disponible"
        }
    }
}

/// Lee de CoreMotion la actividad y los pasos de las últimas 36 h para el detector de sueño.
///
/// No está atado al hilo principal: CoreMotion llama de regreso en sus propias colas.
enum MotionReader {
    static var access: MotionAccess {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unavailable }
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: return .allowed
        case .notDetermined: return .notAsked
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// nil si no hay permiso, el iPhone no tiene el sensor o no hay datos.
    /// La primera vez, la consulta de actividad es la que muestra el aviso de permiso.
    static func read(until now: Date = Date()) async -> MotionInput? {
        let current = access
        guard current == .allowed || current == .notAsked else { return nil }
        let (start, count) = SleepDetector.bins(endingAt: now)
        guard count > 0 else { return nil }
        let end = SleepDetector.binStart(start, count)
        // Se pide desde 12 h antes para saber cuánto llevaba la muestra que estaba en curso al inicio.
        guard let samples = await activities(from: start.addingTimeInterval(-12 * 3600), to: end),
              samples.contains(where: { $0.end > start }) else { return nil }
        let steps = await stepBins(from: start, count: count)
        return MotionInput(start: start, binCount: count, samples: samples, steps: steps)
    }

    // MARK: Actividad

    private static func activities(from start: Date, to end: Date) async -> [MotionSample]? {
        let manager = CMMotionActivityManager()
        return await withCheckedContinuation { (continuation: CheckedContinuation<[MotionSample]?, Never>) in
            manager.queryActivityStarting(from: start, to: end, to: OperationQueue()) { activities, error in
                withExtendedLifetime(manager) {}
                guard error == nil, let activities = activities else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: MotionReader.samples(from: activities, until: end))
            }
        }
    }

    /// Cada actividad dura hasta que empieza la siguiente; la última, hasta `end`.
    private static func samples(from activities: [CMMotionActivity], until end: Date) -> [MotionSample] {
        let sorted = activities.sorted { $0.startDate < $1.startDate }
        var out: [MotionSample] = []
        for (i, activity) in sorted.enumerated() {
            let next = i + 1 < sorted.count ? sorted[i + 1].startDate : end
            let stop = min(next, end)
            guard stop > activity.startDate else { continue }
            out.append(MotionSample(start: activity.startDate, end: stop, kind: kind(of: activity),
                                    confidence: activity.confidence.rawValue))
        }
        return out
    }

    /// Si CoreMotion marca varias a la vez (quieto en un semáforo dentro del coche), gana el movimiento.
    private static func kind(of activity: CMMotionActivity) -> MotionKind {
        if activity.automotive { return .automotive }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }

    // MARK: Pasos

    /// Pasos por bin de 5 min. Primero pregunta por hora y solo baja a bins de 5 min en las horas con pasos.
    private static func stepBins(from start: Date, count: Int) async -> [Int] {
        guard CMPedometer.isStepCountingAvailable() else { return [] }
        let pedometer = CMPedometer()
        var bins = [Int](repeating: 0, count: count)
        var first = 0
        while first < count {
            let last = min(count, first + 12)
            let hour = await stepCount(pedometer, from: SleepDetector.binStart(start, first), to: SleepDetector.binStart(start, last))
            if hour > 0 {
                for i in first..<last {
                    bins[i] = await stepCount(pedometer, from: SleepDetector.binStart(start, i), to: SleepDetector.binStart(start, i + 1))
                }
            }
            first = last
        }
        return bins
    }

    private static func stepCount(_ pedometer: CMPedometer, from start: Date, to end: Date) async -> Int {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }
}
