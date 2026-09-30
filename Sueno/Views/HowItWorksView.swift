import SwiftUI

struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Explainer(
                    title: "Deuda de sueño",
                    text: "Compara lo que dormiste contra lo que necesitas en las últimas 14 noches. Anoche pesa 15 %; el 85 % restante se reparte entre las 13 anteriores y cada noche hacia atrás pesa 15 % menos. Las noches sin datos no cuentan y la deuda nunca baja de cero.",
                    formula: "D = Σ 14 · wᵢ · (N − Sᵢ)\nw₁ = 0.15,  wᵢ ∝ 0.85^(i−2),  Σ wᵢ = 1"
                )
                Explainer(
                    title: "Necesidad de sueño",
                    text: "Con 21 días o más de datos busca «rebotes»: días en que dormiste al menos 1 h más que el promedio de tus 5 registros anteriores, después de una racha corta. Con 3 rebotes o más la estima; si no, usa tu valor manual.",
                    formula: "N = promedio + 0.3 · (mediana de rebotes − promedio)\nlímites: 5 h a 11.5 h"
                )
                Explainer(
                    title: "Energía potencial",
                    text: "Tu tope de energía del día según tu deuda. Con 6 h de deuda queda alrededor de 78 %.",
                    formula: "E_pot = 100 · e^(−D/24)"
                )
                Explainer(
                    title: "Curva de energía (modelo SAFTE)",
                    text: "Un tanque que se vacía mientras estás despierto y un reloj interno con un ciclo de 24 h y otro de 12 h. La deuda baja el nivel del tanque al despertar y hace más fuertes los bajones. Al despertar se resta la modorra (inercia del sueño).",
                    formula: "E(t) = 100·R/Rc + (a₁ + a₂·(Rc−R)/Rc)·C(t) − I\nR = R₀ − 30·Tₐ,  R₀ = Rc·(1 − min(0.3, 0.012·D))\nC(t) = cos(2π(t−p)/24) + 0.5·cos(4π(t−p−3)/24)\nI = min(10, 5 + 0.25·D) · e^(−Tₐ/0.45)\nRc = 2880, a₁ = 7, a₂ = 5, p = mitad de tu sueño + 15 h"
                )
                Explainer(
                    title: "Ventanas del día",
                    text: "La modorra dura 90 min desde que despiertas. Los picos son donde la curva está en su 40 % más alto entre el bajón y cada pico; el bajón, en su 35 % más bajo. La ventana de melatonina es 1 h alrededor de tu hora natural de dormir, y la relajación es la hora anterior.",
                    formula: "hora natural = mitad de tu sueño − N/2\nmelatonina = [natural − 45 min, natural + 15 min]"
                )
                Explainer(
                    title: "Hora sugerida para dormir",
                    text: "Para despertar a tu hora con tu necesidad completa más un poco para pagar deuda, contando 15 min para dormirte. Nunca antes de que empiece tu ventana de melatonina, porque más temprano te costaría dormirte.",
                    formula: "dormir = despertar − (N + min(1 h, D/10)) − 15 min"
                )
                Explainer(
                    title: "Energía ahora",
                    text: "Tu energía potencial ajustada por el punto de la curva en el que vas: en tu pico es el 100 % de tu potencial y en lo más bajo, el 75 %.",
                    formula: "E_ahora = E_pot · (0.75 + 0.25 · nivel)"
                )
                Text("Es una aproximación con el modelo público SAFTE y reglas propias de esta app; no es el algoritmo de RISE ni un dispositivo médico.")
                    .font(.footnote)
                    .foregroundStyle(Theme.tintaSuave)
            }
            .padding(20)
        }
        .background(Theme.noche.ignoresSafeArea())
        .navigationTitle("Cómo se calcula")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct Explainer: View {
    let title: String
    let text: String
    let formula: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.display(22))
                .foregroundStyle(Theme.tinta)
            Text(text)
                .font(.callout)
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            Text(formula)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.ambar)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.nocheHonda, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
