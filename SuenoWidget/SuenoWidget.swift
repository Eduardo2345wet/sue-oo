import WidgetKit
import SwiftUI

struct SuenoEntry: TimelineEntry {
    let date: Date
    let summary: SleepSummary
    let shared: Bool
}

struct SuenoProvider: TimelineProvider {
    func placeholder(in context: Context) -> SuenoEntry {
        SuenoEntry(date: Date(), summary: SleepEngine.summary(data: AppData(), now: Date()), shared: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SuenoEntry) -> Void) {
        let now = Date()
        let data = SharedStore.load()
        completion(SuenoEntry(date: now, summary: SleepEngine.summary(data: data, now: now), shared: SharedStore.isShared))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuenoEntry>) -> Void) {
        let now = Date()
        let data = SharedStore.load()
        let shared = SharedStore.isShared
        // La curva ya se conoce, así que se calculan 8 h por adelantado (cada 30 min).
        let entries = (0..<16).map { i -> SuenoEntry in
            let date = now.addingTimeInterval(Double(i) * 30 * 60)
            return SuenoEntry(date: date, summary: SleepEngine.summary(data: data, now: date), shared: shared)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct SuenoWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: SuenoEntry

    var body: some View {
        if !entry.shared {
            Text("Abre Sueño: el widget todavía no puede leer tus datos.")
                .font(.caption)
                .foregroundStyle(Theme.tintaSuave)
        } else {
            switch family {
            case .systemMedium:
                MediumWidgetView(summary: entry.summary)
            case .accessoryCircular:
                CircularWidgetView(summary: entry.summary)
            case .accessoryRectangular:
                RectangularWidgetView(summary: entry.summary)
            case .accessoryInline:
                Text("\(entry.summary.headline), deuda \(Fmt.debt(entry.summary.debt))")
            default:
                SmallWidgetView(summary: entry.summary)
            }
        }
    }
}

struct SmallWidgetView: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.headline)
                .font(Theme.display(15))
                .foregroundStyle(summary.headlineColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let until = summary.untilText {
                Text(until)
                    .font(.caption2)
                    .foregroundStyle(Theme.tintaSuave)
            }
            Spacer(minLength: 4)
            Text(Fmt.debt(summary.debt))
                .font(Theme.display(30))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .foregroundStyle(Theme.debtColor(summary.debt))
            Text("de deuda de sueño")
                .font(.caption2)
                .foregroundStyle(Theme.tintaSuave)
            Text("Energía \(Fmt.percent(summary.potential))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tinta)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumWidgetView: View {
    let summary: SleepSummary

    var body: some View {
        HStack(spacing: 12) {
            SmallWidgetView(summary: summary)
                .frame(width: 120)
            EnergyChartView(plan: summary.plan, now: summary.now, compact: true)
        }
    }
}

struct CircularWidgetView: View {
    let summary: SleepSummary

    var body: some View {
        Gauge(value: min(100, max(0, summary.potential)), in: 0...100) {
            Text("Energía")
        } currentValueLabel: {
            Text("\(Int(summary.potential.rounded()))")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

struct RectangularWidgetView: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(summary.headline)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            if let until = summary.untilText {
                Text(until)
                    .font(.caption)
            }
            Text("Deuda \(Fmt.debt(summary.debt)), energía \(Fmt.percent(summary.potential))")
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EnergiaWidget: Widget {
    let kind = "SuenoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuenoProvider()) { entry in
            SuenoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Theme.noche
                }
        }
        .configurationDisplayName("Sueño y energía")
        .description("Tu deuda de sueño y en qué parte de tu curva de energía vas.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct SuenoWidgetBundle: WidgetBundle {
    var body: some Widget {
        EnergiaWidget()
    }
}
