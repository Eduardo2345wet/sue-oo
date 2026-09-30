import SwiftUI

@main
struct SuenoApp: App {
    @StateObject var model = AppModel()

    init() {
        Theme.followsClock = true
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

    var body: some View {
        // Revisa la hora cada minuto; cuando cambia la paleta (amanecer, día, anocheciendo, noche)
        // se vuelven a dibujar las pestañas con los colores nuevos.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let sky = SkyPalette.kind(at: context.date)
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
            .id(sky)
            .tint(Theme.ambar)
            .preferredColorScheme(sky == .dia ? .light : .dark)
        }
        .task { await model.detectSleep() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.becameActive()
            }
        }
    }
}
