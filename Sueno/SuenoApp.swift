import SwiftUI

@main
struct SuenoApp: App {
    @StateObject var model = AppModel()

    init() {
        Theme.skyKind = SkyPalette.kind(at: Date())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) var scenePhase
    @State var tab = 0
    /// Solo cambia cuatro veces al día (amanecer, día, anocheciendo, noche).
    @State var sky: SkyPalette.Kind = Theme.skyKind

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Hoy", systemImage: "sun.horizon") }
                .tag(0)
            HistoryView()
                .tabItem { Label("Historial", systemImage: "chart.bar.xaxis") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
                .tag(2)
        }
        // Con otra paleta se vuelven a dibujar las pestañas con los colores nuevos.
        .id(sky)
        .tint(Theme.ambar)
        .preferredColorScheme(sky == .dia ? .light : .dark)
        .task { await model.detectSleep() }
        .task {
            // Revisa la hora cada minuto; solo toca la vista si cambió la paleta.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                updateSky()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                updateSky()
                model.becameActive()
            }
        }
    }

    private func updateSky() {
        let now = SkyPalette.kind(at: Date())
        guard now != sky else { return }
        Theme.skyKind = now
        sky = now
    }
}
