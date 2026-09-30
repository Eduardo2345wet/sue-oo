import SwiftUI

/// Paleta: cielo nocturno índigo, ámbar de amanecer para la energía,
/// azul marea para los bajones y morado para la melatonina.
enum Theme {
    static let noche = Color(red: 27 / 255, green: 31 / 255, blue: 59 / 255)          // #1B1F3B
    static let nocheHonda = Color(red: 19 / 255, green: 22 / 255, blue: 43 / 255)     // #13162B
    static let tinta = Color(red: 237 / 255, green: 234 / 255, blue: 245 / 255)       // #EDEAF5
    static let tintaSuave = Color(red: 154 / 255, green: 160 / 255, blue: 195 / 255)  // #9AA0C3
    static let ambar = Color(red: 242 / 255, green: 165 / 255, blue: 65 / 255)        // #F2A541
    static let marea = Color(red: 91 / 255, green: 141 / 255, blue: 239 / 255)        // #5B8DEF
    static let melatonina = Color(red: 157 / 255, green: 123 / 255, blue: 232 / 255)  // #9D7BE8
    static let alerta = Color(red: 239 / 255, green: 109 / 255, blue: 104 / 255)      // #EF6D68
    static let bien = Color(red: 122 / 255, green: 200 / 255, blue: 150 / 255)        // #7AC896

    /// Números y títulos en serif (New York): se lee tranquilo, como para la noche.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Menos de 5 h está bien, de 5 a 10 ya se siente, más de 10 cuesta varias noches pagarla.
    static func debtColor(_ debt: Double) -> Color {
        if debt < 5 { return bien }
        if debt < 10 { return ambar }
        return alerta
    }
}

extension WindowKind {
    var color: Color {
        switch self {
        case .modorra: return Theme.tintaSuave
        case .picoManana, .picoTarde: return Theme.ambar
        case .bajon: return Theme.marea
        case .relajacion: return Theme.melatonina.opacity(0.6)
        case .melatonina: return Theme.melatonina
        }
    }
}

extension SleepSummary {
    var headline: String {
        isAsleep ? "Durmiendo" : phase.title
    }

    var headlineColor: Color {
        if isAsleep { return Theme.melatonina }
        return phase.kind?.color ?? Theme.tinta
    }

    var untilText: String? {
        if isAsleep {
            return pendingSleepStart.map { "desde las \(Fmt.time($0))" }
        }
        return phase.until.map { "hasta las \(Fmt.time($0))" }
    }
}
