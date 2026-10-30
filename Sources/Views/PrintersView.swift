import SwiftUI

struct PrintersView: View {
    @EnvironmentObject var store: Store
    @State private var editing: PrinterProfile?
    @State private var pendingDelete: PrinterProfile?

    var body: some View {
        List {
            ForEach(store.printers) { p in
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "printer").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).font(.headline)
                            Text("\(Int(p.powerWatts)) W • depreciation \(Fmt.money(p.depreciationPerHour, store.settings.currencySymbol))/h")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if p.id == store.settings.defaultPrinterID {
                            Text("Default").font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = p }

                    if p.id != store.settings.defaultPrinterID {
                        Button { store.settings.defaultPrinterID = p.id } label: {
                            Image(systemName: "star")
                        }
                        .buttonStyle(.borderless).help("Set as default")
                    }
                    Button(role: .destructive) { pendingDelete = p } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless).help("Delete printer")
                }
                .padding(.vertical, 3)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingDelete = p } label: { Label("Delete", systemImage: "trash") }
                    Button { editing = p } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                }
                .contextMenu {
                    Button { editing = p } label: { Label("Edit", systemImage: "pencil") }
                    Button { duplicate(p) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button { store.settings.defaultPrinterID = p.id } label: { Label("Set as default", systemImage: "star") }
                    Divider()
                    Button(role: .destructive) { pendingDelete = p } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .navigationTitle("Printers")
        .toolbar {
            Button {
                editing = PrinterProfile(name: "New Printer", powerWatts: 100,
                                         purchasePrice: 10000, lifetimeHours: 4000)
            } label: { Label("Add", systemImage: "plus") }
        }
        .sheet(item: $editing) { p in
            PrinterEditor(printer: p, symbol: store.settings.currencySymbol) { upsert($0) }
        }
        .confirmationDialog("Delete this printer?",
                            isPresented: deleteDialogPresented,
                            presenting: pendingDelete) { p in
            Button("Delete \(p.name)", role: .destructive) { delete(p); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func upsert(_ p: PrinterProfile) {
        if let i = store.printers.firstIndex(where: { $0.id == p.id }) {
            store.printers[i] = p
        } else {
            store.printers.append(p)
            if store.settings.defaultPrinterID == nil { store.settings.defaultPrinterID = p.id }
        }
    }
    private func duplicate(_ p: PrinterProfile) {
        var copy = p
        copy.id = UUID()
        copy.name = p.name + " (copy)"
        if let i = store.printers.firstIndex(where: { $0.id == p.id }) {
            store.printers.insert(copy, at: i + 1)
        } else {
            store.printers.append(copy)
        }
    }
    private func delete(_ p: PrinterProfile) {
        store.printers.removeAll { $0.id == p.id }
        if store.settings.defaultPrinterID == p.id {
            store.settings.defaultPrinterID = store.printers.first?.id
        }
    }
}

struct PrinterEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var printer: PrinterProfile
    let symbol: String
    let onSave: (PrinterProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Printer").font(.headline).padding([.top, .horizontal], 20)
            Form {
                TextField("Name", text: $printer.name)
                TextField("Average power draw (W)", value: $printer.powerWatts, format: .number)
                TextField("Purchase price (\(symbol))", value: $printer.purchasePrice, format: .number)
                TextField("Expected lifetime (hours)", value: $printer.lifetimeHours, format: .number)
                LabeledContent("Depreciation / hour",
                               value: Fmt.money(printer.depreciationPerHour, symbol))
                Toggle("Use custom electricity price", isOn: $printer.useCustomElectricity)
                if printer.useCustomElectricity {
                    TextField("Electricity (\(symbol)/kWh)", value: $printer.electricityPricePerKWh, format: .number)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(printer); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 400)
    }
}
