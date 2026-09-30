import SwiftUI
import Charts

/// La curva de energía del día como un horizonte: franjas de color para cada ventana,
/// la curva de 0 a 100 % de tu día (verde arriba, rojo abajo) y un punto que marca dónde vas ahorita.
struct EnergyChartView: View {
    let plan: DayPlan
    let now: Date
    var compact: Bool = false

    /// Relativo a lo que se dibuja: el punto más bajo queda en 10 % y el más alto en 90 %.
    /// La escala sale de toda la curva (también la hora después de la melatonina),
    /// así el final no se recorta ni se queda pegado en 0 %.
    private func percent(_ value: Double, lo: Double, hi: Double) -> Double {
        guard hi - lo > 0.01 else { return 50 }
        return 10 + 80 * (value - lo) / (hi - lo)
    }

    var body: some View {
        let yLow = -4.0
        let yHigh = 104.0
        let showNow = now >= plan.start && now <= plan.end
        let values = plan.points.map { $0.value }
        let lo = values.min() ?? plan.lo
        let hi = values.max() ?? plan.hi

        Chart {
            ForEach(plan.windows.filter { $0.start < plan.end }) { w in
                RectangleMark(
                    xStart: .value("Inicio", w.start),
                    xEnd: .value("Fin", min(w.end, plan.end)),
                    yStart: .value("Base", yLow),
                    yEnd: .value("Tope", yHigh)
                )
                .foregroundStyle(w.kind.color.opacity(compact ? w.kind.bandOpacity + 0.06 : w.kind.bandOpacity))
            }

            ForEach(plan.points) { point in
                AreaMark(
                    x: .value("Hora", point.date),
                    yStart: .value("Base", 0),
                    yEnd: .value("Energía", percent(point.value, lo: lo, hi: hi))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Theme.energiaAlta.opacity(0.34), location: 0),
                            .init(color: Theme.energiaMedia.opacity(0.2), location: 0.5),
                            .init(color: Theme.energiaBaja.opacity(0.06), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            ForEach(plan.points) { point in
                LineMark(
                    x: .value("Hora", point.date),
                    y: .value("Energía", percent(point.value, lo: lo, hi: hi))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.energiaAlta, Theme.energiaMedia, Theme.energiaBaja],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            if showNow {
                RuleMark(x: .value("Ahora", now))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    .foregroundStyle(Theme.tinta.opacity(0.8))
                PointMark(
                    x: .value("Ahora", now),
                    y: .value("Energía", percent(plan.value(at: now), lo: lo, hi: hi))
                )
                .symbolSize(compact ? 60 : 320)
                .foregroundStyle(Theme.tinta.opacity(0.22))
                PointMark(
                    x: .value("Ahora", now),
                    y: .value("Energía", percent(plan.value(at: now), lo: lo, hi: hi))
                )
                .symbolSize(compact ? 30 : 120)
                .foregroundStyle(Theme.puntoAhora)
            }
        }
        .chartXScale(domain: plan.start...plan.end)
        .chartYScale(domain: yLow...yHigh)
        .chartPlotStyle { plot in plot.clipped() }
        .chartYAxis {
            // En el widget no caben las etiquetas: sin valores, no se dibuja el eje.
            AxisMarks(position: .leading, values: compact ? [] : [0.0, 25.0, 50.0, 75.0, 100.0]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Theme.tinta.opacity(0.08))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.tintaSuave)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: compact ? 4 : 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
        .accessibilityLabel("Curva de energía del día, de 0 a 100 %")
    }
}
