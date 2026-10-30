import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section("Currency") {
                TextField("Symbol", text: bind(\.currencySymbol))
            }
            Section("Defaults") {
                TextField("Electricity price (\(store.settings.currencySymbol)/kWh)",
                          value: bind(\.electricityPricePerKWh), format: .number)
                TextField("Default fail %", value: bind(\.defaultFailPercent), format: .number)
                TextField("Default markup %", value: bind(\.defaultMarkupPercent), format: .number)
                TextField("Default labor (\(store.settings.currencySymbol))",
                          value: bind(\.defaultLaborCost), format: .number)
            }
            Section("Default printer") {
                Picker("Printer", selection: bind(\.defaultPrinterID)) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.printers) { p in Text(p.name).tag(Optional(p.id)) }
                }
            }
            Section {
                Text("Data is stored locally in Application Support/PrintCostCalc.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func bind<T>(_ kp: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: kp] },
                set: { store.settings[keyPath: kp] = $0 })
    }
}
