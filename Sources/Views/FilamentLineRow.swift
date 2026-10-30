import SwiftUI

/// One editable filament row in the calculator (per AMS slot or a purge line).
struct FilamentLineRow: View {
    @Binding var line: FilamentLine
    let filaments: [Filament]
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: line.detectedColorHex))
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(.secondary.opacity(0.35)))

            VStack(alignment: .leading, spacing: 1) {
                Text(line.isPurge ? "Purge / waste" : "Slot \(line.slot)")
                    .font(.subheadline).bold()
                Text(line.detectedType).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 100, alignment: .leading)

            Picker("", selection: filamentBinding) {
                Text("— pick filament —").tag(UUID?.none)
                ForEach(filaments) { f in
                    Text(f.displayName).tag(Optional(f.id))
                }
            }
            .labelsHidden()
            .frame(width: 240)

            HStack(spacing: 3) {
                TextField("g", value: $line.grams, format: .number)
                    .frame(width: 58).multilineTextAlignment(.trailing)
                Text("g").foregroundStyle(.secondary)
            }

            HStack(spacing: 3) {
                Text(symbol).foregroundStyle(.secondary)
                TextField("price", value: $line.pricePerKg, format: .number)
                    .frame(width: 64).multilineTextAlignment(.trailing)
                Text("/kg").foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            Text(Fmt.money(line.lineCost, symbol))
                .font(.subheadline).monospacedDigit()
                .frame(width: 86, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    /// When a filament is picked, also adopt its price.
    private var filamentBinding: Binding<UUID?> {
        Binding(
            get: { line.matchedFilamentID },
            set: { newID in
                line.matchedFilamentID = newID
                if let f = filaments.first(where: { $0.id == newID }) {
                    line.pricePerKg = f.pricePerKg
                    line.filamentLabel = f.displayName
                } else {
                    line.filamentLabel = nil
                }
            }
        )
    }
}
