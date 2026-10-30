import SwiftUI

enum FilamentSort: String, CaseIterable, Identifiable {
    case name = "Name"
    case priceLow = "Price ↑"
    case priceHigh = "Price ↓"
    var id: String { rawValue }
}

struct FilamentsView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Filament?
    @State private var pendingDelete: Filament?

    @State private var sort: FilamentSort = .name
    @State private var filterType: String = "All"
    @State private var filterColor: String = "All"

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            List {
                ForEach(visibleFilaments) { f in
                    HStack(spacing: 10) {
                        Circle().fill(colorSwatch(f)).frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(.secondary.opacity(0.3)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.displayName).font(.headline)
                            Text(f.materialLabel).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.money(f.pricePerKg, store.settings.currencySymbol) + " /kg")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = f }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { pendingDelete = f } label: { Label("Delete", systemImage: "trash") }
                        Button { editing = f } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                    }
                    .contextMenu {
                        Button { editing = f } label: { Label("Edit", systemImage: "pencil") }
                        Button { duplicate(f) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Divider()
                        Button(role: .destructive) { pendingDelete = f } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Filaments")
        .toolbar {
            Button {
                editing = Filament(brand: "Generic", type: "PLA", pricePerKg: 600, colorHex: "#1E90FF")
            } label: { Label("Add", systemImage: "plus") }
        }
        .sheet(item: $editing) { f in
            FilamentEditor(filament: f) { saved in upsert(saved) }
        }
        .confirmationDialog("Delete this filament?",
                            isPresented: deleteDialogPresented,
                            presenting: pendingDelete) { f in
            Button("Delete \(f.displayName)", role: .destructive) { delete(f); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 14) {
            Picker("Sort", selection: $sort) {
                ForEach(FilamentSort.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu).frame(width: 150)

            Picker("Type", selection: $filterType) {
                Text("All types").tag("All")
                ForEach(allTypes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).frame(width: 150)

            Picker("Color", selection: $filterColor) {
                Text("All colors").tag("All")
                ForEach(allColors, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).frame(width: 160)

            Spacer()
            Text("\(visibleFilaments.count) of \(store.filaments.count)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: - Derived data

    private func colorLabel(_ f: Filament) -> String { f.colorName.isEmpty ? "Any" : f.colorName }
    private func colorSwatch(_ f: Filament) -> Color {
        f.colorName.isEmpty ? Color.secondary.opacity(0.3) : Color(hex: f.colorHex)
    }

    private var allTypes: [String] {
        Array(Set(store.filaments.map(\.type))).sorted()
    }
    private var allColors: [String] {
        Array(Set(store.filaments.map(colorLabel))).sorted()
    }

    private var visibleFilaments: [Filament] {
        var list = store.filaments
        if filterType != "All" { list = list.filter { $0.type == filterType } }
        if filterColor != "All" { list = list.filter { colorLabel($0) == filterColor } }
        switch sort {
        case .name:      list.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .priceLow:  list.sort { $0.pricePerKg < $1.pricePerKg }
        case .priceHigh: list.sort { $0.pricePerKg > $1.pricePerKg }
        }
        return list
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: - Mutations

    private func upsert(_ f: Filament) {
        if let i = store.filaments.firstIndex(where: { $0.id == f.id }) {
            store.filaments[i] = f
        } else {
            store.filaments.append(f)
        }
    }
    private func duplicate(_ f: Filament) {
        var copy = f
        copy.id = UUID()
        copy.colorName = f.colorName.isEmpty ? "Copy" : f.colorName + " (copy)"
        if let i = store.filaments.firstIndex(where: { $0.id == f.id }) {
            store.filaments.insert(copy, at: i + 1)
        } else {
            store.filaments.append(copy)
        }
    }
    private func delete(_ f: Filament) { store.filaments.removeAll { $0.id == f.id } }
}

struct FilamentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var filament: Filament
    let onSave: (Filament) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: filament.colorHex)).frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.3)))
                Text(filament.displayName).font(.headline)
            }
            .padding([.top, .horizontal], 20)

            Form {
                ComboField(title: "Brand", value: $filament.brand, options: FilamentPresets.brands)
                ComboField(title: "Material", value: $filament.type, options: FilamentPresets.materials)
                ComboField(title: "Variant", value: $filament.variant, options: FilamentPresets.variants)
                ColorChoiceField(colorName: $filament.colorName, colorHex: $filament.colorHex)
                TextField("Price per kg", value: $filament.pricePerKg, format: .number)
                TextField("Density (g/cm³)", value: $filament.density, format: .number)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(filament); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 400)
    }
}
