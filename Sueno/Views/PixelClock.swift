import SwiftUI

/// Reloj pixelado: un disco con cielo de día y de noche gira detrás de una ventana dorada.
/// Un fotograma por hora: 15° por hora, con el sol arriba a las 12 pm y la luna a las 12 am.
struct PixelClock: View {
    let date: Date
    var size: CGFloat = 84

    var body: some View {
        let hour = Calendar.current.component(.hour, from: date)
        Canvas { ctx, canvasSize in
            let scale = canvasSize.width / 64
            ctx.scaleBy(x: scale, y: scale)
            let crisp = FillStyle(antialiased: false)

            ctx.fill(PixelClock.frameOuter, with: .color(PixelClock.rgb(0x8A6A2E)), style: crisp)
            ctx.fill(PixelClock.frameInner, with: .color(PixelClock.rgb(0xE3B341)), style: crisp)

            var disc = ctx
            disc.clip(to: PixelClock.window)
            disc.translateBy(x: 32, y: 32)
            disc.rotate(by: .degrees(PixelClock.rotation(hour: hour)))
            disc.translateBy(x: -32, y: -32)
            for (x, y, w, h, color) in PixelClock.sky {
                disc.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(PixelClock.rgb(color)), style: crisp)
            }

            // La manecilla fija de arriba.
            ctx.fill(Path(CGRect(x: 30, y: 4, width: 4, height: 10)), with: .color(PixelClock.rgb(0x4A3614)), style: crisp)
            ctx.fill(Path(CGRect(x: 31, y: 5, width: 2, height: 7)), with: .color(PixelClock.rgb(0xF5E6B8)), style: crisp)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Reloj del día")
    }

    /// Grados que gira el disco: 0 a las 12 pm, 180 a las 12 am.
    static func rotation(hour: Int) -> Double {
        -Double(hour - 12) * 15
    }

    // MARK: Dibujo (coordenadas de 64 × 64, igual que el diseño)

    static let frameOuter = stepPath("M18,2 H46 V6 H54 V10 H58 V18 H62 V46 H58 V54 H54 V58 H46 V62 H18 V58 H10 V54 H6 V46 H2 V18 H6 V10 H10 V6 H18 Z")
    static let frameInner = stepPath("M20,4 H44 V8 H52 V12 H56 V20 H60 V44 H56 V52 H52 V56 H44 V60 H20 V56 H12 V52 H8 V44 H4 V20 H8 V12 H12 V8 H20 Z")
    static let window = stepPath("M20,8 H44 V12 H52 V20 H56 V44 H52 V52 H44 V56 H20 V52 H12 V44 H8 V20 H12 V12 H20 Z")

    /// Cielo, atardecer, anochecer, noche, sol, luna y estrellas: (x, y, ancho, alto, color).
    static let sky: [(CGFloat, CGFloat, CGFloat, CGFloat, UInt32)] = [
        (0, 0, 64, 32, 0x6FB7FF),
        (0, 24, 64, 8, 0xF29B5B),
        (0, 32, 64, 8, 0x3A2F6B),
        (0, 40, 64, 24, 0x141838),
        (26, 6, 12, 12, 0xFFE066),
        (28, 8, 8, 8, 0xFFF3B0),
        (26, 46, 12, 12, 0xD9DCEB),
        (28, 48, 4, 4, 0xAEB3CC),
        (33, 53, 3, 3, 0xAEB3CC),
        (12, 44, 2, 2, 0xFFFFFF),
        (48, 50, 2, 2, 0xFFFFFF),
        (16, 56, 2, 2, 0xFFFFFF),
        (46, 42, 2, 2, 0xFFFFFF),
    ]

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Convierte una ruta SVG hecha solo de M, H, V y Z (escalones de pixel art) en un Path.
    static func stepPath(_ svg: String) -> Path {
        var path = Path()
        for point in PixelClockShape.points(svg) {
            if path.isEmpty {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Lee los puntos de una ruta SVG con solo M, H, V y Z.
enum PixelClockShape {
    static func points(_ svg: String) -> [CGPoint] {
        var out: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        for token in svg.split(separator: " ") {
            guard let command = token.first else { continue }
            let args = token.dropFirst().split(separator: ",").compactMap { Double($0) }.map { CGFloat($0) }
            switch command {
            case "M" where args.count == 2:
                x = args[0]
                y = args[1]
            case "H" where args.count == 1:
                x = args[0]
            case "V" where args.count == 1:
                y = args[0]
            default:
                continue
            }
            out.append(CGPoint(x: x, y: y))
        }
        return out
    }
}
