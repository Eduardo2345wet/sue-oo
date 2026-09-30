import Foundation
import UserNotifications

enum Notifier {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Reprograma los dos avisos diarios con las horas calculadas hoy.
    /// Se llama cada vez que cambian tus datos o abres la app.
    static func reschedule(for data: AppData, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["melatonina", "dormir"])
        let summary = SleepEngine.summary(data: data, now: now)

        if data.settings.notifyMelatonin {
            schedule(id: "melatonina",
                     at: summary.plan.melatoninStart,
                     title: "Empieza tu ventana de melatonina",
                     body: "Es el mejor momento para dormirte. Baja luces y pantallas.")
        }
        if data.settings.notifyBedtime {
            schedule(id: "dormir",
                     at: summary.suggestedBedtime.addingTimeInterval(-30 * 60),
                     title: "En 30 minutos: hora de dormir",
                     body: "Ve cerrando pendientes para acostarte a tiempo.")
        }
    }

    private static func schedule(id: String, at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
