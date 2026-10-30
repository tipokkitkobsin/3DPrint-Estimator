import SwiftUI

/// The live cost breakdown card with per-job fail% and markup% sliders (and reset-to-default).
struct BreakdownView: View {
    let b: CostBreakdown
    let symbol: String
    @Binding var failPercent: Double
    @Binding var markupPercent: Double
    var defaultFail: Double = 10
    var defaultMarkup: Double = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cost breakdown").font(.headline)
            line("Material", b.material)
            line("Energy", b.energy)
            line("Machine (depreciation)", b.machine)
            line("Labor", b.labor)
            Divider()
            line("Subtotal", b.base, bold: true)
            slider("Fail", value: $failPercent, range: 0...100, amount: b.failMarkup,
                   isDefault: failPercent == defaultFail) { failPercent = defaultFail }
            line("Cost (incl. expected waste)", b.cost, bold: true)
            slider("Markup", value: $markupPercent, range: 0...300, amount: b.markupAmount,
                   isDefault: markupPercent == defaultMarkup) { markupPercent = defaultMarkup }
            Divider()
            HStack {
                Text("Final price").font(.title3).bold()
                Spacer()
                Text(Fmt.moneyWhole(b.finalPrice, symbol))
                    .font(.title).bold().foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func line(_ label: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label).fontWeight(bold ? .semibold : .regular)
            Spacer()
            Text(Fmt.money(value, symbol)).monospacedDigit().fontWeight(bold ? .semibold : .regular)
        }
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                        amount: Double, isDefault: Bool, reset: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text("\(label)  \(Int(value.wrappedValue))%")
                .frame(width: 104, alignment: .leading)
            Slider(value: value, in: range, step: 1)
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(isDefault)
            .help("Reset to default (\(Int(label == "Fail" ? value.wrappedValue : value.wrappedValue))%)")
            Text(Fmt.money(amount, symbol)).monospacedDigit()
                .frame(width: 84, alignment: .trailing).foregroundStyle(.secondary)
        }
    }
}
