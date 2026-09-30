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
    static let lavanda = Color(red: 185 / 255, green: 156 / 255, blue: 240 / 255)     // #B99CF0
    // Degradado de la curva: verde arriba, amarillo en medio, rojo abajo.
    static let energiaAlta = Color(red: 76 / 255, green: 211 / 255, blue: 138 / 255)   // #4CD38A
    static let energiaMedia = Color(red: 242 / 255, green: 201 / 255, blue: 76 / 255)  // #F2C94C
    static let energiaBaja = Color(red: 239 / 255, green: 91 / 255, blue: 91 / 255)    // #EF5B5B
    static let bien = Color(red: 122 / 255, green: 200 / 255, blue: 150 / 255)        // #7AC896

    /// Números y títulos en serif (New York): se lee tranquilo, como para la noche.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
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
        case .modorra, .bajon: return Theme.marea
        case .picoManana, .picoTarde: return Theme.ambar
        case .relajacion: return Theme.lavanda
        case .melatonina: return Theme.melatonina
        }
    }

    /// Opacidad de la franja de esta ventana en la curva.
    var bandOpacity: Double {
        switch self {
        case .modorra, .bajon: return 0.14
        case .picoManana, .picoTarde: return 0.12
        case .relajacion: return 0.16
        case .melatonina: return 0.22
        }
    }
}

/// Tarjeta del diseño: fondo índigo, esquinas de 28 y sombra suave.
struct CardStyle: ViewModifier {
    var padding = EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.noche, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color(red: 4 / 255, green: 5 / 255, blue: 18 / 255).opacity(0.45), radius: 16, y: 12)
    }
}

extension View {
    func card(_ padding: EdgeInsets = EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20)) -> some View {
        modifier(CardStyle(padding: padding))
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
