import Foundation
import SwiftUI

/// Single source of truth: persisted library/history, plus the live (transient) order being edited.
@MainActor
final class Store: ObservableObject {
    // Persisted
    @Published var settings: AppSettings { didSet { save() } }
    @Published var filaments: [Filament] { didSet { save() } }
    @Published var printers: [PrinterProfile] { didSet { save() } }
    @Published var jobs: [Job] { didSet { save() } }

    // Transient UI/order state (not persisted) — lives here so it survives tab switches.
    @Published var selectedTab: SidebarItem = .calculate
    @Published var orderItems: [OrderItem] = []
    @Published var orderPrinterID: UUID?
    @Published var orderLabor: Double = 0
    @Published var orderFail: Double = 10
    @Published var orderMarkup: Double = 50
    @Published var editingJobID: UUID?
    @Published var pendingOpenURL: URL?

    private let fileURL: URL
    private var loaded = false

    private struct Persisted: Codable {
        var settings: AppSettings
        var filaments: [Filament]
        var printers: [PrinterProfile]
        var jobs: [Job]
    }

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("PrintCostCalc", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")

        if let data = try? Data(contentsOf: fileURL),
           let p = try? JSONDecoder().decode(Persisted.self, from: data) {
            settings = p.settings
            filaments = p.filaments
            printers = p.printers
            jobs = p.jobs
        } else {
            let a1 = Store.seedPrinter()
            var s = AppSettings()
            s.defaultPrinterID = a1.id
            settings = s
            filaments = Store.seedFilaments()
            printers = [a1]
            jobs = []
        }
        loaded = true
        // Apply order defaults from settings.
        orderPrinterID = settings.defaultPrinterID ?? printers.first?.id
        orderFail = settings.defaultFailPercent
        orderMarkup = settings.defaultMarkupPercent
        orderLabor = settings.defaultLaborCost
        save()
    }

    func save() {
        guard loaded else { return }
        let p = Persisted(settings: settings, filaments: filaments, printers: printers, jobs: jobs)
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: fileURL) }
    }

    // MARK: - Matching / lookups

    func bestMatch(type: String, colorHex: String) -> Filament? {
        let t = type.lowercased()
        if let exact = filaments.first(where: {
            $0.type.lowercased() == t && $0.colorHex.caseInsensitiveCompare(colorHex) == .orderedSame
        }) { return exact }
        return filaments.first { $0.type.lowercased() == t }
    }

    func printer(id: UUID?) -> PrinterProfile? {
        if let id, let p = printers.first(where: { $0.id == id }) { return p }
        return printers.first { $0.id == settings.defaultPrinterID } ?? printers.first
    }

    // MARK: - Order building (lives in the store so it is view-lifecycle independent)

    func addFiles(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            let slice = FileImporter.load(url: url)
            if scoped { url.stopAccessingSecurityScopedResource() }
            let plateIndex = slice.plates.count > 1 ? allPlatesTag : 0
            let (seconds, lines) = makeLines(slice, plateIndex)
            orderItems.append(OrderItem(slice: slice, plateIndex: plateIndex,
                                        printSeconds: seconds, lines: lines))
        }
    }

    func makeLines(_ slice: SliceData, _ plateIndex: Int) -> (Double, [FilamentLine]) {
        if plateIndex == allPlatesTag {
            let (seconds, slots) = aggregate(slice.plates)
            return (seconds, slots.map { makeLine($0, file: slice.fileName) })
        } else if plateIndex >= 0, plateIndex < slice.plates.count {
            let plate = slice.plates[plateIndex]
            return (plate.printSeconds, plate.slots.map { makeLine($0, file: slice.fileName) })
        }
        return (0, [])
    }

    private func aggregate(_ plates: [PlateData]) -> (Double, [SlotData]) {
        var seconds = 0.0
        var byKey: [String: SlotData] = [:]
        var order: [String] = []
        for plate in plates {
            seconds += plate.printSeconds
            for slot in plate.slots {
                let key = slot.type.lowercased() + "|" + slot.colorHex.lowercased()
                if var existing = byKey[key] {
                    existing.grams += slot.grams
                    existing.lengthMM += slot.lengthMM
                    byKey[key] = existing
                } else {
                    byKey[key] = slot
                    order.append(key)
                }
            }
        }
        let slots = order.enumerated().map { index, key -> SlotData in
            var s = byKey[key]!
            s.slot = index + 1
            return s
        }
        return (seconds, slots)
    }

    private func makeLine(_ slot: SlotData, file: String) -> FilamentLine {
        let match = bestMatch(type: slot.type, colorHex: slot.colorHex)
        return FilamentLine(slot: slot.slot, detectedType: slot.type,
                            detectedColorHex: slot.colorHex, grams: slot.grams,
                            matchedFilamentID: match?.id, pricePerKg: match?.pricePerKg ?? 0,
                            filamentLabel: match?.displayName, sourceFile: file)
    }

    private func synthSlice(_ name: String, _ seconds: Double, _ lines: [FilamentLine],
                            preview: Data? = nil) -> SliceData {
        let slots = lines.map { SlotData(slot: $0.slot, type: $0.detectedType,
                                         colorHex: $0.detectedColorHex, grams: $0.grams, lengthMM: 0) }
        var plate = PlateData(name: "Plate 1", printSeconds: seconds, slots: slots)
        plate.previewSmall = preview
        plate.preview = preview
        return SliceData(fileName: name, plates: [plate], isSliced: true, note: nil)
    }

    /// Load a saved job back into the live order for full editing, and jump to Calculate.
    func loadJob(_ job: Job) {
        editingJobID = job.id
        orderPrinterID = job.printerID ?? settings.defaultPrinterID ?? printers.first?.id
        orderLabor = job.laborCost
        orderFail = job.failPercent
        orderMarkup = job.markupPercent

        if let files = job.files {
            orderItems = files.map { jf in
                OrderItem(slice: synthSlice(jf.fileName, jf.printSeconds, jf.lines, preview: jf.previewPNG),
                          plateIndex: 0, printSeconds: jf.printSeconds, lines: jf.lines, quantity: jf.quantity)
            }
        } else {
            var keys: [String] = []
            var seen = Set<String>()
            for l in job.lines {
                let f = l.sourceFile ?? job.fileName
                if seen.insert(f).inserted { keys.append(f) }
            }
            let n = max(keys.count, 1)
            orderItems = keys.map { f in
                let group = job.lines.filter { ($0.sourceFile ?? job.fileName) == f }
                let qty = group.first?.quantity ?? 1
                let perUnit = group.map { line -> FilamentLine in var l = line; l.quantity = 1; return l }
                let secs = job.printSeconds / Double(n) / Double(max(qty, 1))
                return OrderItem(slice: synthSlice(f, secs, perUnit),
                                 plateIndex: 0, printSeconds: secs, lines: perUnit, quantity: qty)
            }
        }
        selectedTab = .calculate
    }

    func clearOrder() {
        orderItems = []
        editingJobID = nil
    }

    // MARK: - Seeds

    static func seedPrinter() -> PrinterProfile {
        PrinterProfile(name: "Bambu Lab A1 + AMS 2 Pro",
                       powerWatts: 100, purchasePrice: 12000, lifetimeHours: 4000,
                       useCustomElectricity: false, electricityPricePerKWh: 4.5)
    }

    static func seedFilaments() -> [Filament] {
        [
            Filament(brand: "Bambu Lab", type: "PLA", variant: "Basic",
                     colorName: "White", pricePerKg: 799, colorHex: "#FFFFFF", density: 1.24),
            Filament(brand: "Bambu Lab", type: "PLA", variant: "Silk",
                     colorName: "Blue", pricePerKg: 999, colorHex: "#1E90FF", density: 1.24),
            Filament(brand: "Polymaker", type: "PLA", variant: "Matte",
                     colorName: "Black", pricePerKg: 750, colorHex: "#1A1A1A", density: 1.22),
            Filament(brand: "Generic", type: "PLA", variant: "",
                     colorName: "Blue", pricePerKg: 600, colorHex: "#1E90FF", density: 1.24),
            Filament(brand: "Generic", type: "PETG", variant: "",
                     colorName: "Green", pricePerKg: 750, colorHex: "#2ECC71", density: 1.27)
        ]
    }
}
