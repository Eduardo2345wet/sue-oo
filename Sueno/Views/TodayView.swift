import SwiftUI

struct TodayView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = model.summary(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    PhaseHeader(summary: summary)
                    if let proposal = model.proposal {
                        DetectionCard(proposal: proposal)
                    }
                    EnergyCard(summary: summary, now: context.date)
                    NumbersBlock(summary: summary)
                    DayWindowsList(summary: summary)
                    TonightBlock(summary: summary)
                    SleepButton(summary: summary)
                    if !summary.hasAnyData {
                        Text("Todavía no hay noches registradas, así que la curva usa tu hora de despertar de Ajustes. Registra con el botón, agrega noches en Historial o impórtalas desde Salud con el Atajo.")
                            .font(.footnote)
                            .foregroundStyle(Theme.tintaSuave)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
            .background(Theme.fondo.ignoresSafeArea())
        }
    }
}

struct PhaseHeader: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("HOY")
                        .font(.system(size: 14, weight: .medium))
                        .tracking(1.1)
                        .foregroundStyle(Theme.tintaSuave)
                    Text(summary.headline)
                        .font(Theme.display(40))
                        .foregroundStyle(summary.headlineColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PixelClock(date: summary.now)
            }
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }

    var detail: String {
        if summary.isAsleep {
            let since = summary.pendingSleepStart.map { Fmt.sentence("Desde las \(Fmt.time($0))") + " " } ?? ""
            return since + "Cuando despiertes, toca «Ya me desperté»."
        }
        let phase = summary.phase
        if let until = phase.until {
            let lead = Fmt.sentence("\(phase.kind == .melatonina ? "Hasta" : "Dura hasta") las \(Fmt.time(until))")
            return phase.detail.isEmpty ? lead : lead + " " + phase.detail
        }
        return phase.detail
    }
}

struct EnergyCard: View {
    let summary: SleepSummary
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tu energía")
                    .font(Theme.display(17))
                    .foregroundStyle(Theme.tinta)
                Spacer()
                Text(Fmt.time(now))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tintaSuave)
            }
            .padding(.horizontal, 2)
            EnergyChartView(plan: summary.plan, now: now)
                .frame(height: 160)
        }
        .card()
    }
}

struct NumbersBlock: View {
    let summary: SleepSummary

    var body: some View {
        HStack(spacing: 16) {
            StatCard(value: String(format: "%.1f", max(0, summary.debt)), unit: "h", label: "Deuda de sueño")
            StatCard(value: "\(Int(summary.potential.rounded()))", unit: "%", label: "Energía potencial")
        }
    }
}

struct StatCard: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.display(44))
                    .tracking(-0.9)
                    .monospacedDigit()
                    .foregroundStyle(Theme.tinta)
                Text(unit)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.tintaSuave)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.tintaSuave)
        }
        .card(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
    }
}

struct DayWindowsList: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tu día")
                    .font(Theme.display(17))
                    .foregroundStyle(Theme.tinta)
                if summary.plan.wakeIsEstimated {
                    Text("Despertar estimado a las \(Fmt.time(summary.plan.wake)); registra tu noche para afinarlo.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.tintaSuave)
                }
            }
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            ForEach(summary.plan.windows) { w in
                WindowRow(window: w, now: summary.now)
            }
        }
        .card(EdgeInsets(top: 24, leading: 8, bottom: 12, trailing: 8))
    }
}

struct WindowRow: View {
    let window: EnergyWindow
    let now: Date

    var body: some View {
        let current = now >= window.start && now < window.end
        let past = window.end <= now
        HStack(spacing: 14) {
            Circle()
                .fill(window.kind.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(window.kind.title)
                    .font(.system(size: 16, weight: current ? .semibold : .medium))
                    .foregroundStyle(Theme.tinta)
                if current {
                    Text("Ahora")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(window.kind.color)
                }
            }
            Spacer(minLength: 8)
            Text(Fmt.range(window.start, window.end))
                .font(.system(size: 14))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(current ? Theme.tinta : Theme.tintaSuave)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: current ? 60 : 52)
        .background {
            if current {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(window.kind.color.opacity(0.14))
            }
        }
        .opacity(past ? 0.45 : 1)
    }
}

struct TonightBlock: View {
    let summary: SleepSummary

    var body: some View {
        let late = summary.now > summary.suggestedBedtime && !summary.isAsleep
        VStack(alignment: .leading, spacing: 8) {
            Text("Esta noche")
                .font(Theme.display(17))
                .foregroundStyle(Theme.tinta)
            Text(late ? "Ya pasó tu hora: \(Fmt.time(summary.suggestedBedtime))" : "Acuéstate a las \(Fmt.time(summary.suggestedBedtime))")
                .font(Theme.display(28))
                .foregroundStyle(Theme.melatonina)
            Text("Para despertar a las \(Fmt.time(summary.targetWake)) con unas \(Fmt.hm(summary.plannedSleepHours)) de sueño. Tu ventana de melatonina va de \(Fmt.range(summary.plan.melatoninStart, summary.plan.melatoninEnd)).")
                .font(.system(size: 15))
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
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
            .foregroundStyle(Theme.sobreColor)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
    }
}
