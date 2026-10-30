import SwiftUI
import UniformTypeIdentifiers

struct CalculateView: View {
    @EnvironmentObject var store: Store
    @State private var isTargeted = false
    @State private var showImporter = false
    @State private var savedFlash = false
    @State private var enlargedPlate: PlateData?

    private var combinedLines: [FilamentLine] {
        store.orderItems.flatMap { it in
            it.lines.map { line -> FilamentLine in
                var l = line
                l.quantity = it.quantity
                l.sourceFile = it.slice.fileName
                return l
            }
        }
    }
    private var totalSeconds: Double {
        store.orderItems.reduce(0) { $0 + $1.printSeconds * Double($1.quantity) }
    }
    private var breakdown: CostBreakdown {
        let p = store.printer(id: store.orderPrinterID)
        let elec = (p?.useCustomElectricity == true) ? (p?.electricityPricePerKWh ?? 0) : store.settings.electricityPricePerKWh
        return CostCalculator.breakdown(
            lines: combinedLines, printSeconds: totalSeconds,
            powerWatts: p?.powerWatts ?? 0, electricityPricePerKWh: elec,
            depreciationPerHour: p?.depreciationPerHour ?? 0,
            laborCost: store.orderLabor, failPercent: store.orderFail, markupPercent: store.orderMarkup)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dropZone
                if !store.orderItems.isEmpty {
                    if store.editingJobID != nil { editingBanner }
                    globalControls
                    ForEach($store.orderItems) { $item in itemCard($item) }
                    BreakdownView(b: breakdown, symbol: store.settings.currencySymbol,
                                  failPercent: $store.orderFail, markupPercent: $store.orderMarkup,
                                  defaultFail: store.settings.defaultFailPercent,
                                  defaultMarkup: store.settings.defaultMarkupPercent)
                    actionButtons
                }
            }
            .padding(20)
        }
        .navigationTitle("Calculate")
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importTypes, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.addFiles(urls) }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in handleDrop(providers) }
        .sheet(item: $enlargedPlate) { plate in PlatePreviewSheet(plate: plate) }
    }

    private var dropZone: some View {
        let active = store.orderItems.isEmpty
        return RoundedRectangle(cornerRadius: 14)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
            .frame(height: active ? 220 : 64)
            .overlay {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down").font(active ? .system(size: 40) : .title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(active ? "Drop .gcode or .3mf files here" : "Drop more files to add to this order")
                            .font(active ? .title3 : .body).bold()
                        Text("Multiple files combine into one bill • or click Add")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button(active ? "Add…" : "Add files…") { showImporter = true }
                        .keyboardShortcut("o", modifiers: .command)
                }
                .padding()
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(isTargeted ? 0.08 : 0)))
    }

    private var editingBanner: some View {
        HStack {
            Image(systemName: "pencil.circle.fill").foregroundStyle(.blue)
            Text("Editing a saved order — \u{201C}Update saved\u{201D} overwrites it.")
            Spacer()
            Button("New order") { store.clearOrder() }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.12)))
    }

    private var globalControls: some View {
        HStack(spacing: 16) {
            Picker("Printer", selection: $store.orderPrinterID) {
                ForEach(store.printers) { p in Text(p.name).tag(Optional(p.id)) }
            }
            .frame(width: 250)
            HStack(spacing: 4) {
                Text("Labor").foregroundStyle(.secondary)
                Text(store.settings.currencySymbol).foregroundStyle(.secondary)
                TextField("0", value: $store.orderLabor, format: .number)
                    .frame(width: 60).multilineTextAlignment(.trailing)
            }
            Spacer()
            Text("\(store.orderItems.count) file\(store.orderItems.count == 1 ? "" : "s") • \(Fmt.duration(totalSeconds)) total")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func itemCard(_ item: Binding<OrderItem>) -> some View {
        let it = item.wrappedValue
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                previewStrip(it)
                VStack(alignment: .leading, spacing: 1) {
                    Text(it.slice.fileName).font(.headline)
                    if let note = it.slice.note {
                        Label(note, systemImage: "exclamationmark.triangle")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
                Spacer()
                if it.slice.plates.count > 1 {
                    Picker("", selection: item.plateIndex) {
                        Text("All plates").tag(allPlatesTag)
                        ForEach(it.slice.plates.indices, id: \.self) { i in
                            Text(it.slice.plates[i].name).tag(i)
                        }
                    }
                    .labelsHidden().frame(width: 140)
                    .onChange(of: item.wrappedValue.plateIndex) { _, _ in reload(item) }
                }
                HStack(spacing: 4) {
                    Text("Time").foregroundStyle(.secondary)
                    TextField("min", value: minutesBinding(item), format: .number)
                        .frame(width: 52).multilineTextAlignment(.trailing)
                    Text("min").foregroundStyle(.secondary)
                }
                Stepper(value: item.quantity, in: 1...999) {
                    Text("× \(it.quantity)").monospacedDigit()
                }
                .frame(width: 96)
                Button(role: .destructive) { store.orderItems.removeAll { $0.id == it.id } } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless).help("Remove this file")
            }

            ForEach(item.lines) { $line in
                HStack(spacing: 6) {
                    FilamentLineRow(line: $line, filaments: store.filaments,
                                    symbol: store.settings.currencySymbol)
                    Button(role: .destructive) {
                        item.wrappedValue.lines.removeAll { $0.id == line.id }
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless).help("Remove this line")
                }
            }

            HStack {
                Button { addPurge(item) } label: { Label("Add purge / waste", systemImage: "plus") }
                    .buttonStyle(.borderless).font(.callout)
                Spacer()
                Text("Material " + Fmt.money(itemMaterial(it) * Double(it.quantity), store.settings.currencySymbol)
                     + (it.quantity > 1 ? "  (×\(it.quantity))" : ""))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { saveJob() } label: {
                Label(store.editingJobID == nil ? "Save to history" : "Update saved", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            Button {
                QuoteExporter.copyToClipboard(QuoteExporter.text(job: makeJob(), symbol: store.settings.currencySymbol))
            } label: { Label("Copy quote", systemImage: "doc.on.clipboard") }
            Menu {
                Button("PDF…") { QuoteExporter.savePDF(job: makeJob(), symbol: store.settings.currencySymbol) }
                Button("PNG…") { QuoteExporter.savePNG(job: makeJob(), symbol: store.settings.currencySymbol) }
            } label: { Label("Export", systemImage: "arrow.down.doc") }
            .frame(width: 120)
            Button(role: .destructive) { store.clearOrder() } label: { Label("Clear", systemImage: "trash") }
            if savedFlash {
                Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green).transition(.opacity)
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private var importTypes: [UTType] {
        var t: [UTType] = [.data]
        if let g = UTType(filenameExtension: "gcode") { t.append(g) }
        if let m = UTType(filenameExtension: "3mf") { t.append(m) }
        return t
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let u = item as? URL { url = u }
                if let url { DispatchQueue.main.async { store.addFiles([url]) } }
            }
        }
        return true
    }

    private func reload(_ item: Binding<OrderItem>) {
        let (seconds, lines) = store.makeLines(item.wrappedValue.slice, item.wrappedValue.plateIndex)
        item.wrappedValue.printSeconds = seconds
        item.wrappedValue.lines = lines
    }

    private func addPurge(_ item: Binding<OrderItem>) {
        let it = item.wrappedValue
        let avg = it.lines.isEmpty ? 0 : it.lines.map(\.pricePerKg).reduce(0, +) / Double(it.lines.count)
        let nextSlot = (it.lines.map(\.slot).max() ?? 0) + 1
        item.wrappedValue.lines.append(
            FilamentLine(slot: nextSlot, detectedType: "Purge", detectedColorHex: "#888888",
                         grams: 0, matchedFilamentID: nil, pricePerKg: avg, isPurge: true,
                         filamentLabel: nil, sourceFile: it.slice.fileName))
    }

    /// Plate renders for this file: all plates when "All plates" is selected, else the chosen one.
    private func previewStrip(_ it: OrderItem) -> some View {
        let plates: [PlateData] = it.plateIndex == allPlatesTag
            ? it.slice.plates
            : (it.slice.plates[safe: it.plateIndex].map { [$0] } ?? [])
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(plates) { p in
                    PlateThumb(plate: p, size: 64) { enlargedPlate = p }
                }
            }
        }
        .frame(width: plates.count > 1 ? 150 : 64, height: 64)
    }

    private func itemMaterial(_ it: OrderItem) -> Double {
        it.lines.reduce(0) { $0 + $1.lineCost }
    }

    private func plateName(_ it: OrderItem) -> String {
        if it.plateIndex == allPlatesTag { return "All plates" }
        return it.slice.plates[safe: it.plateIndex]?.name ?? "Plate 1"
    }

    private func minutesBinding(_ item: Binding<OrderItem>) -> Binding<Double> {
        Binding(get: { item.wrappedValue.printSeconds / 60 },
                set: { item.wrappedValue.printSeconds = $0 * 60 })
    }

    private func makeJob() -> Job {
        let items = store.orderItems
        let p = store.printer(id: store.orderPrinterID)
        let elec = (p?.useCustomElectricity == true) ? (p?.electricityPricePerKWh ?? 0) : store.settings.electricityPricePerKWh
        let name = items.count == 1 ? items[0].slice.fileName : "Order — \(items.count) files"
        let plate = items.count == 1 ? plateName(items[0]) : "\(items.count) files"
        let files = items.map { it -> JobFile in
            let plate = it.plateIndex == allPlatesTag ? it.slice.plates.first : it.slice.plates[safe: it.plateIndex]
            return JobFile(fileName: it.slice.fileName, printSeconds: it.printSeconds,
                           quantity: it.quantity, lines: it.lines,
                           previewPNG: plate?.previewSmall ?? plate?.preview)
        }
        return Job(fileName: name, plateName: plate,
                   printerID: p?.id, printerName: p?.name ?? "—",
                   printSeconds: totalSeconds, lines: combinedLines, laborCost: store.orderLabor,
                   failPercent: store.orderFail, markupPercent: store.orderMarkup,
                   electricityPricePerKWh: elec, powerWatts: p?.powerWatts ?? 0,
                   depreciationPerHour: p?.depreciationPerHour ?? 0, breakdown: breakdown, files: files)
    }

    private func saveJob() {
        guard !store.orderItems.isEmpty else { return }
        var job = makeJob()
        if let eid = store.editingJobID, let i = store.jobs.firstIndex(where: { $0.id == eid }) {
            job.id = eid
            job.date = store.jobs[i].date
            store.jobs[i] = job
        } else {
            store.jobs = [job] + store.jobs
            store.editingJobID = job.id
        }
        withAnimation { savedFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { savedFlash = false }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
