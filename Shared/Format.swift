import Foundation

enum Fmt {
    /// "22:10" o "10:10 p.m." según la configuración del iPhone.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "22:10 a 23:10"
    static func range(_ a: Date, _ b: Date) -> String {
        "\(time(a)) a \(time(b))"
    }

    /// "7 h 45 min"
    static func hm(_ hours: Double) -> String {
        let totalMinutes = Int((max(0, hours) * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }

    /// "6.3 h"
    static func debt(_ hours: Double) -> String {
        String(format: "%.1f h", max(0, hours))
    }

    /// Cierra una oración con punto sin duplicarlo ("9:30 p.m." ya trae el suyo).
    static func sentence(_ text: String) -> String {
        text.hasSuffix(".") ? text : text + "."
    }

    /// "+12 min", "−8 min" o "0 min"
    static func signedMinutes(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m > 0 { return "+\(m) min" }
        if m < 0 { return "−\(-m) min" }
        return "0 min"
    }

    /// "77 %"
    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded())) %"
    }

    /// "lun, 28 sept"
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
