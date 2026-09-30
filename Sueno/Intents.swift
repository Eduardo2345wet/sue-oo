import AppIntents
import Foundation

struct MeVoyADormirIntent: AppIntent {
    static var title: LocalizedStringResource = "Me voy a dormir"
    static var description = IntentDescription("Guarda la hora en que te vas a dormir.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = SleepActions.runStandalone { (d: inout AppData) -> String in
            SleepActions.startSleep(&d, at: Date())
        }
        return .result(dialog: "\(message)")
    }
}

struct YaMeDesperteIntent: AppIntent {
    static var title: LocalizedStringResource = "Ya me desperté"
    static var description = IntentDescription("Cierra el registro que empezaste con «Me voy a dormir».")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = SleepActions.runStandalone { (d: inout AppData) -> String in
            SleepActions.endSleep(&d, at: Date())
        }
        return .result(dialog: "\(message)")
    }
}

struct ImportarSuenoIntent: AppIntent {
    static var title: LocalizedStringResource = "Importar sueño"
    static var description = IntentDescription("Importa sueño desde texto: una línea por muestra, inicio|fin|tipo, con fechas ISO 8601.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Texto")
    var texto: String

    static var parameterSummary: some ParameterSummary {
        Summary("Importar sueño de \(\.$texto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = texto
        let message = SleepActions.runStandalone { (d: inout AppData) -> String in
            SleepActions.importSleep(&d, text: text)
        }
        return .result(dialog: "\(message)")
    }
}

struct SuenoAtajos: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MeVoyADormirIntent(),
            phrases: [
                "Me voy a dormir en \(.applicationName)",
                "Registrar que me duermo en \(.applicationName)"
            ],
            shortTitle: "Me voy a dormir",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: YaMeDesperteIntent(),
            phrases: [
                "Ya me desperté en \(.applicationName)",
                "Registrar que desperté en \(.applicationName)"
            ],
            shortTitle: "Ya me desperté",
            systemImageName: "sun.max.fill"
        )
    }
}
