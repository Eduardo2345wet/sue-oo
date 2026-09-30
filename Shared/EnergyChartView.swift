import SwiftUI
import Charts

/// La curva de energía del día como un horizonte: franjas de color para cada ventana,
/// la línea ámbar de la curva y un punto que marca dónde vas ahorita.
struct EnergyChartView: View {
    let plan: DayPlan
    let now: Date
    var compact: Bool = false

    var body: some View {
        let yLow = plan.lo - 1.5
        let yHigh = plan.hi + 1.0
        let showNow = now >= plan.start && now <= plan.end

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
                    yStart: .value("Base", yLow),
                    yEnd: .value("Energía", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.ambar.opacity(0.38), Theme.ambar.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            ForEach(plan.points) { point in
                LineMark(
                    x: .value("Hora", point.date),
                    y: .value("Energía", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
                .foregroundStyle(Theme.ambar)
            }

            if showNow {
                RuleMark(x: .value("Ahora", now))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    .foregroundStyle(Theme.tinta.opacity(0.8))
                PointMark(
                    x: .value("Ahora", now),
                    y: .value("Energía", plan.value(at: now))
                )
                .symbolSize(compact ? 60 : 320)
                .foregroundStyle(Theme.tinta.opacity(0.22))
                PointMark(
                    x: .value("Ahora", now),
                    y: .value("Energía", plan.value(at: now))
                )
                .symbolSize(compact ? 30 : 120)
                .foregroundStyle(Color.white)
            }
        }
        .chartXScale(domain: plan.start...plan.end)
        .chartYScale(domain: yLow...yHigh)
        .chartPlotStyle { plot in plot.clipped() }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: compact ? 4 : 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
        .accessibilityLabel("Curva de energía del día")
    }
}
