import SwiftUI

/// Paleta de fondo, tarjetas y texto según la hora: amanecer, día, anocheciendo o noche.
struct SkyPalette {
    enum Kind: String {
        case amanecer, dia, anocheciendo, noche
    }

    let kind: Kind
    let fondo: Color
    let tarjeta: Color
    let tinta: Color
    let tintaSuave: Color
    let sombra: Color
    /// Punto de "ahora" en la curva.
    let puntoAhora: Color

    var isLight: Bool { kind == .dia }

    /// Amanecer de 5 a 8, día de 8 a 18, anocheciendo de 18 a 22 y noche de 22 a 5.
    static func kind(at date: Date, calendar: Calendar = .current) -> Kind {
        switch calendar.component(.hour, from: date) {
        case 5..<8: return .amanecer
        case 8..<18: return .dia
        case 18..<22: return .anocheciendo
        default: return .noche
        }
    }

    static func palette(_ kind: Kind) -> SkyPalette {
        switch kind {
        case .amanecer: return amanecer
        case .dia: return dia
        case .anocheciendo: return anocheciendo
        case .noche: return noche
        }
    }

    static let amanecer = SkyPalette(kind: .amanecer, fondo: .hex(0x3A2437), tarjeta: .hex(0x4E2F48),
                                     tinta: .hex(0xFCEDE6), tintaSuave: .hex(0xD9B6C3),
                                     sombra: Color(red: 26 / 255, green: 10 / 255, blue: 22 / 255).opacity(0.45),
                                     puntoAhora: .white)
    static let dia = SkyPalette(kind: .dia, fondo: .hex(0xEAF3FB), tarjeta: .hex(0xFFFFFF),
                                tinta: .hex(0x14213D), tintaSuave: .hex(0x4F5D78),
                                sombra: Color(red: 20 / 255, green: 33 / 255, blue: 61 / 255).opacity(0.10),
                                puntoAhora: .hex(0x14213D))
    static let anocheciendo = SkyPalette(kind: .anocheciendo, fondo: .hex(0x2A1B33), tarjeta: .hex(0x3A2646),
                                         tinta: .hex(0xF4E8F2), tintaSuave: .hex(0xC4A9C9),
                                         sombra: Color(red: 12 / 255, green: 5 / 255, blue: 18 / 255).opacity(0.45),
                                         puntoAhora: .white)
    static let noche = SkyPalette(kind: .noche, fondo: .hex(0x0B0E1F), tarjeta: .hex(0x151935),
                                  tinta: .hex(0xE6E8F5), tintaSuave: .hex(0x8E95BC),
                                  sombra: Color(red: 0, green: 0, blue: 8 / 255).opacity(0.55),
                                  puntoAhora: .white)
}

extension Color {
    static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }
}

/// Colores de la app. Fondo, tarjetas y texto cambian con la hora (solo en la app;
/// el widget se queda con la paleta de noche porque WidgetKit lo dibuja por adelantado).
/// Ámbar para la energía, azul marea para los bajones y morado para la melatonina.
enum Theme {
    /// Paleta actual. La cambia RootView cuando pasa de amanecer a día, etc.; el widget no la toca.
    static var skyKind: SkyPalette.Kind = .noche

    static var sky: SkyPalette { SkyPalette.palette(skyKind) }

    static var fondo: Color { sky.fondo }
    static var tarjeta: Color { sky.tarjeta }
    static var tinta: Color { sky.tinta }
    static var tintaSuave: Color { sky.tintaSuave }
    static var sombra: Color { sky.sombra }
    static var puntoAhora: Color { sky.puntoAhora }

    /// Texto sobre botones de color (ámbar o morado): siempre oscuro para que se lea.
    static let sobreColor = Color.hex(0x13162B)
    /// Título de los picos de día: el ámbar no se lee sobre blanco.
    static let ambarOscuro = Color.hex(0xB45F06)

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

    /// Números y títulos.
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

/// Tarjeta del diseño: esquinas de 28 y sombra suave, con los colores de la hora.
struct CardStyle: ViewModifier {
    var padding = EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.tarjeta, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.sombra, radius: 16, y: 12)
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
        if Theme.sky.isLight, phase.kind == .picoManana || phase.kind == .picoTarde {
            return Theme.ambarOscuro
        }
        return phase.kind?.color ?? Theme.tinta
    }

    var untilText: String? {
        if isAsleep {
            return pendingSleepStart.map { "desde las \(Fmt.time($0))" }
        }
        return phase.until.map { "hasta las \(Fmt.time($0))" }
    }
}
