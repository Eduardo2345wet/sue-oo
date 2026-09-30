import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State var exporting = false
    @State var importingBackup = false
    @State var backupMessage: String? = nil

    var body: some View {
        let summary = model.summary()

        NavigationStack {
            Form {
                Section {
                    Toggle("Calcularla con mis datos", isOn: settingsBinding.autoNeed)
                    Stepper(value: settingsBinding.manualNeedHours, in: 5...11.5, step: 0.25) {
                        HStack {
                            Text("Valor manual")
                            Spacer()
                            Text(Fmt.hm(model.data.settings.manualNeedHours))
                                .monospacedDigit()
                                .foregroundStyle(Theme.tintaSuave)
                        }
                    }
                } header: {
                    Text("Tu necesidad de sueño")
                } footer: {
                    Text(needFooter(summary.need))
                }

                Section {
                    DatePicker("Quiero despertar a las", selection: wakeBinding, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Despertar")
                } footer: {
                    Text("Se usa para tu hora sugerida de dormir y, mientras no haya datos, para estimar tu curva.")
                }

                Section {
                    Toggle("Cuando empieza la ventana de melatonina", isOn: notifyBinding(\.notifyMelatonin))
                    Toggle("30 min antes de la hora de dormir", isOn: notifyBinding(\.notifyBedtime))
                } header: {
                    Text("Avisos")
                }

                Section {
                    NavigationLink(destination: ImportView()) {
                        Text("Importar sueño pegando texto")
                    }
                    NavigationLink(destination: HowItWorksView()) {
                        Text("Cómo se calcula todo")
                    }
                } header: {
                    Text("Datos")
                }

                Section {
                    Button("Exportar respaldo") { exporting = true }
                    Button("Cargar respaldo") { importingBackup = true }
                    if let backupMessage {
                        Text(backupMessage)
                            .foregroundStyle(Theme.tintaSuave)
                    }
                } header: {
                    Text("Respaldo")
                } footer: {
                    Text("Un archivo .json con todos tus registros y ajustes. Guárdalo en Archivos o iCloud Drive.")
                }

                Section {
                    LabeledContent("Datos compartidos con el widget", value: SharedStore.isShared ? "Sí" : "No")
                    if let group = SharedStore.groupID {
                        Text(group)
                            .font(.caption2)
                            .foregroundStyle(Theme.tintaSuave)
                    }
                    NavigationLink(destination: DetectionDiagnosticsView()) {
                        LabeledContent("Detección de sueño", value: detectionSummary)
                    }
                } header: {
                    Text("Diagnóstico")
                } footer: {
                    Text(SharedStore.isShared
                         ? "Todo bien: el widget lee los mismos datos que la app."
                         : "El widget no puede leer tus datos. Reinstala con AltStore o SideStore y acepta conservar las extensiones.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.nocheHonda.ignoresSafeArea())
            .navigationTitle("Ajustes")
            .fileExporter(isPresented: $exporting,
                          document: BackupDocument(data: model.exportData()),
                          contentType: .json,
                          defaultFilename: "sueno-respaldo") { result in
                switch result {
                case .success: backupMessage = "Respaldo guardado."
                case .failure(let error): backupMessage = "No se pudo exportar: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let raw = try? Data(contentsOf: url) {
                        backupMessage = model.importBackup(raw)
                    } else {
                        backupMessage = "No pude leer ese archivo."
                    }
                case .failure(let error):
                    backupMessage = "No se pudo abrir: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: Bindings

    var settingsBinding: Binding<AppSettings> {
        Binding(
            get: { model.data.settings },
            set: { newValue in model.setSettings(newValue) }
        )
    }

    var wakeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: model.data.settings.wakeHour,
                                      minute: model.data.settings.wakeMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var s = model.data.settings
                s.wakeHour = parts.hour ?? 7
                s.wakeMinute = parts.minute ?? 0
                model.setSettings(s)
            }
        )
    }

    func notifyBinding(_ key: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.data.settings[keyPath: key] },
            set: { on in
                var s = model.data.settings
                s[keyPath: key] = on
                model.setSettings(s)
                if on {
                    Task { _ = await Notifier.requestPermission() }
                }
            }
        )
    }

    /// El ajuste aprendido de la detección, en corto.
    var detectionSummary: String {
        let a = SleepDetector.adjustment(from: model.data.detection.corrections)
        if a.isActive {
            return "\(Fmt.signedMinutes(a.startMinutes)) / \(Fmt.signedMinutes(a.endMinutes))"
        }
        return "Sin ajuste (\(a.corrections) de \(SleepDetector.minCorrections))"
    }

    func needFooter(_ need: NeedInfo) -> String {
        if need.isEstimated {
            return "Usando la estimada con tus datos: \(Fmt.hm(need.hours)), con \(need.rebounds) noches de rebote en \(need.nightsWithData) días registrados."
        }
        if model.data.settings.autoNeed {
            if need.nightsWithData < 21 {
                return "Para estimarla necesito al menos 21 días con datos (llevas \(need.nightsWithData)). Mientras, uso tu valor manual."
            }
            return "Todavía no encuentro suficientes noches de rebote (llevas \(need.rebounds) de 3). Mientras, uso tu valor manual."
        }
        if let estimate = need.estimate {
            return "Usando tu valor manual. Con tus datos, la estimación sería \(Fmt.hm(estimate))."
        }
        return "Usando tu valor manual."
    }
}

/// Archivo de respaldo (.json) para exportar o cargar.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ImportView: View {
    @EnvironmentObject var model: AppModel
    @State var text = ""
    @State var result: String? = nil

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .font(.system(.footnote, design: .monospaced))
                Button("Pegar del portapapeles") {
                    text = UIPasteboard.general.string ?? ""
                }
            } header: {
                Text("Texto del Atajo")
            } footer: {
                Text("Una línea por muestra: inicio|fin|tipo, con las fechas en formato ISO 8601. Lo normal es que el Atajo lo mande solo con la acción «Importar sueño»; esto es por si quieres hacerlo a mano.")
            }

            Section {
                Button("Importar") {
                    result = model.importText(text)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let result {
                    Text(result)
                        .foregroundStyle(Theme.tintaSuave)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.nocheHonda.ignoresSafeArea())
        .navigationTitle("Importar sueño")
    }
}
