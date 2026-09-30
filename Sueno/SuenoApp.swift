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
    @State private var selectedTab: Int = 0
    @State private var showHowItWorks: Bool = false

    var body: some View {
        Group {
            if showHowItWorks {
                NavigationStack {
                    HowItWorksView()
                }
            } else {
                TabView(selection: $selectedTab) {
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
                .tint(Theme.ambar)
            }
        }
        .task {
            configureLaunchArguments()
            await model.detectSleep()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.becameActive()
            }
        }
    }

    private func configureLaunchArguments() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "-screen"), idx + 1 < args.count {
            let screen = args[idx + 1]
            switch screen {
            case "1":
                selectedTab = 0
            case "2":
                selectedTab = 1
            case "3":
                selectedTab = 2
            case "4":
                showHowItWorks = true
            default:
                break
            }
        }
    }
}
