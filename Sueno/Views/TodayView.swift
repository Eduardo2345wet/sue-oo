import SwiftUI

struct TodayView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = model.summary(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    PhaseHeader(summary: summary)
                    EnergyChartView(plan: summary.plan, now: context.date)
                        .frame(height: 210)
                    NumbersBlock(summary: summary)
                    DayWindowsList(summary: summary)
                    TonightBlock(summary: summary)
                    SleepButton(summary: summary)
                    if !summary.hasAnyData {
                        Text("Todavía no hay noches registradas, así que la curva usa tu hora de despertar de Ajustes. Registra con el botón, agrega noches en Historial o impórtalas desde Salud con el Atajo.")
                            .font(.footnote)
                            .foregroundStyle(Theme.tintaSuave)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Theme.noche.ignoresSafeArea())
        }
    }
}

struct PhaseHeader: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.headline)
                .font(Theme.display(34))
                .foregroundStyle(summary.headlineColor)
            Text(detail)
                .font(.callout)
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var detail: String {
        if summary.isAsleep {
            let since = summary.pendingSleepStart.map { "Desde las \(Fmt.time($0))\n" } ?? ""
            return since + "Cuando despiertes, toca «Ya me desperté»."
        }
        let phase = summary.phase
        if let until = phase.until {
            return "Hasta las \(Fmt.time(until))\n\(phase.detail)"
        }
        return phase.detail
    }
}

struct NumbersBlock: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.debt(summary.debt))
                        .font(Theme.display(44))
                        .monospacedDigit()
                        .foregroundStyle(Theme.debtColor(summary.debt))
                    Text("de deuda de sueño")
                        .font(.footnote)
                        .foregroundStyle(Theme.tintaSuave)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.percent(summary.potential))
                        .font(Theme.display(44))
                        .monospacedDigit()
                        .foregroundStyle(Theme.tinta)
                    Text("de energía potencial")
                        .font(.footnote)
                        .foregroundStyle(Theme.tintaSuave)
                }
            }
            Text("Energía ahora: \(Fmt.percent(summary.energyNow)). Calculado con \(summary.nightsWithData14) de 14 noches registradas y una necesidad de \(Fmt.hm(summary.need.hours))\(summary.need.isEstimated ? " (estimada con tus datos)" : "").")
                .font(.footnote)
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DayWindowsList: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu día")
                .font(Theme.display(22))
                .foregroundStyle(Theme.tinta)
            Text(summary.plan.wakeIsEstimated
                 ? "Despertar estimado a las \(Fmt.time(summary.plan.wake)); registra tu noche para afinarlo."
                 : "Despertaste a las \(Fmt.time(summary.plan.wake)).")
                .font(.footnote)
                .foregroundStyle(Theme.tintaSuave)
            ForEach(summary.plan.windows) { w in
                HStack(spacing: 12) {
                    Circle()
                        .fill(w.kind.color)
                        .frame(width: 9, height: 9)
                    Text(w.kind.title)
                        .foregroundStyle(Theme.tinta)
                    Spacer()
                    Text(Fmt.range(w.start, w.end))
                        .monospacedDigit()
                        .foregroundStyle(Theme.tintaSuave)
                }
                .font(.subheadline)
                .opacity(w.end < summary.now ? 0.45 : 1)
            }
        }
    }
}

struct TonightBlock: View {
    let summary: SleepSummary

    var body: some View {
        let late = summary.now > summary.suggestedBedtime && !summary.isAsleep
        VStack(alignment: .leading, spacing: 6) {
            Text("Esta noche")
                .font(Theme.display(22))
                .foregroundStyle(Theme.tinta)
            Text(late ? "Ya pasó tu hora: \(Fmt.time(summary.suggestedBedtime))" : "Acuéstate a las \(Fmt.time(summary.suggestedBedtime))")
                .font(Theme.display(28))
                .foregroundStyle(Theme.melatonina)
            Text("Para despertar a las \(Fmt.time(summary.targetWake)) con unas \(Fmt.hm(summary.plannedSleepHours)) de sueño. Tu ventana de melatonina va de \(Fmt.range(summary.plan.melatoninStart, summary.plan.melatoninEnd)).")
                .font(.callout)
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SleepButton: View {
    @EnvironmentObject var model: AppModel
    let summary: SleepSummary
    @State var message: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                message = summary.isAsleep ? model.endSleep() : model.startSleep()
            } label: {
                Label(summary.isAsleep ? "Ya me desperté" : "Me voy a dormir",
                      systemImage: summary.isAsleep ? "sun.max.fill" : "moon.zzz.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(summary.isAsleep ? Theme.ambar : Theme.melatonina)
            .foregroundStyle(Theme.nocheHonda)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
    }
}
