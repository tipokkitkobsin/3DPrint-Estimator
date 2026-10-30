import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var selected: Job?
    @State private var pendingDelete: Job?

    var body: some View {
        Group {
            if store.jobs.isEmpty {
                ContentUnavailableView("No saved jobs yet",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("Calculate a print and tap “Save to history.”"))
            } else {
                List {
                    ForEach(store.jobs) { job in
                        HStack(spacing: 8) {
                            row(job)
                                .contentShape(Rectangle())
                                .onTapGesture { selected = job }
                            Button { selected = job } label: {
                                Image(systemName: "info.circle")
                            }.buttonStyle(.borderless).help("View details")
                            Button(role: .destructive) { pendingDelete = job } label: {
                                Image(systemName: "trash")
                            }.buttonStyle(.borderless).help("Delete job")
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { pendingDelete = job } label: { Label("Delete", systemImage: "trash") }
                            Button { store.loadJob(job) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .sheet(item: $selected) { job in
            JobDetailView(job: job).environmentObject(store)
        }
        .confirmationDialog("Delete this saved job?",
                            isPresented: deleteDialogPresented,
                            presenting: pendingDelete) { job in
            Button("Delete \(job.fileName)", role: .destructive) { delete(job); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func row(_ job: Job) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(job.fileName).font(.headline)
                Text("\(Fmt.date(job.date)) • \(job.printerName) • \(Fmt.duration(job.printSeconds))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Fmt.moneyWhole(job.breakdown.finalPrice, store.settings.currencySymbol))
                .font(.title3).bold().foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }

    private func delete(_ job: Job) {
        store.jobs.removeAll { $0.id == job.id }
    }
}

/// Read-only detail popup. "Edit" loads the order into the Calculate page.
struct JobDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let job: Job

    private var symbol: String { store.settings.currencySymbol }

    private var fileGroups: [(file: String, lines: [FilamentLine])] {
        var order: [String] = []
        var seen = Set<String>()
        for l in job.lines {
            let f = l.sourceFile ?? job.fileName
            if seen.insert(f).inserted { order.append(f) }
        }
        return order.map { f in (f, job.lines.filter { ($0.sourceFile ?? job.fileName) == f }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.fileName).font(.title3).bold()
                    Text("\(Fmt.date(job.date)) • \(job.printerName) • \(Fmt.duration(job.printSeconds))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.moneyWhole(job.breakdown.finalPrice, symbol))
                    .font(.title2).bold().foregroundStyle(.green)
            }
            .padding(.horizontal, 20)
            if let files = job.files, files.contains(where: { $0.previewPNG != nil }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(files.enumerated()), id: \.offset) { _, f in
                            if let d = f.previewPNG {
                                PlateThumb(plate: PlateData(name: f.fileName, printSeconds: 0, slots: [],
                                                            index: 1, preview: d, previewSmall: d), size: 72)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
            }
            Spacer().frame(height: 16)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fileGroups, id: \.file) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            if fileGroups.count > 1 {
                                Text(group.file).font(.subheadline).bold()
                            }
                            ForEach(group.lines) { l in
                                HStack {
                                    Circle().fill(Color(hex: l.detectedColorHex)).frame(width: 12, height: 12)
                                    Text(l.isPurge ? "Purge" : "Slot \(l.slot)")
                                    Text(l.displaySpec).foregroundStyle(.secondary)
                                    if l.quantity > 1 { Text("×\(l.quantity)").foregroundStyle(.secondary) }
                                    Spacer()
                                    Text(Fmt.grams(l.grams)).foregroundStyle(.secondary).monospacedDigit()
                                    Text(Fmt.money(l.lineCost, symbol)).monospacedDigit().frame(width: 80, alignment: .trailing)
                                }
                            }
                        }
                    }
                    Divider()
                    amount("Material", job.breakdown.material)
                    amount("Energy", job.breakdown.energy)
                    amount("Machine", job.breakdown.machine)
                    amount("Labor", job.breakdown.labor)
                    amount("Fail (\(Int(job.failPercent))%)", job.breakdown.failMarkup)
                    amount("Markup (\(Int(job.markupPercent))%)", job.breakdown.markupAmount)
                    HStack {
                        Text("Final price").font(.headline)
                        Spacer()
                        Text(Fmt.moneyWhole(job.breakdown.finalPrice, symbol)).font(.title3).bold().foregroundStyle(.green)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack(spacing: 12) {
                Button { store.loadJob(job); dismiss() } label: {
                    Label("Edit", systemImage: "pencil")
                }.buttonStyle(.borderedProminent)
                Button("Copy quote") {
                    QuoteExporter.copyToClipboard(QuoteExporter.text(job: job, symbol: symbol))
                }
                Menu {
                    Button("PDF…") { QuoteExporter.savePDF(job: job, symbol: symbol) }
                    Button("PNG…") { QuoteExporter.savePNG(job: job, symbol: symbol) }
                } label: { Text("Export…") }.frame(width: 110)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(20)
        }
        .frame(width: 520, height: 640)
    }

    private func amount(_ label: String, _ value: Double) -> some View {
        HStack { Text(label); Spacer(); Text(Fmt.money(value, symbol)).monospacedDigit() }
    }
}
