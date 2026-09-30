import SwiftUI

@main
struct SuenoApp: App {
    @StateObject var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Hoy", systemImage: "sun.horizon") }
            HistoryView()
                .tabItem { Label("Historial", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.ambar)
        .task { await model.detectSleep() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.becameActive()
            }
        }
    }
}
