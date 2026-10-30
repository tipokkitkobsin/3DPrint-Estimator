import Foundation

/// One priced filament row (one per AMS slot, plus optional purge waste).
struct FilamentLine: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var slot: Int
    var detectedType: String
    var detectedColorHex: String
    var grams: Double
    var matchedFilamentID: UUID?
    var pricePerKg: Double
    var isPurge: Bool = false
    var filamentLabel: String? = nil   // resolved library spec, e.g. "Bambu Lab PLA Silk — Blue"
    var sourceFile: String? = nil      // which uploaded file this line came from (multi-file orders)
    var quantity: Int = 1              // how many times this file/plate is printed

    /// Cost for this line, including the print quantity.
    var lineCost: Double { (grams / 1000.0) * pricePerKg * Double(quantity) }

    /// What to show in quotes: the chosen library spec, else the raw detected type.
    var displaySpec: String {
        if let label = filamentLabel, !label.isEmpty { return label }
        return detectedType
    }

    init(id: UUID = UUID(), slot: Int, detectedType: String, detectedColorHex: String,
         grams: Double, matchedFilamentID: UUID?, pricePerKg: Double, isPurge: Bool = false,
         filamentLabel: String? = nil, sourceFile: String? = nil, quantity: Int = 1) {
        self.id = id
        self.slot = slot
        self.detectedType = detectedType
        self.detectedColorHex = detectedColorHex
        self.grams = grams
        self.matchedFilamentID = matchedFilamentID
        self.pricePerKg = pricePerKg
        self.isPurge = isPurge
        self.filamentLabel = filamentLabel
        self.sourceFile = sourceFile
        self.quantity = quantity
    }

    enum CodingKeys: String, CodingKey {
        case id, slot, detectedType, detectedColorHex, grams, matchedFilamentID
        case pricePerKg, isPurge, filamentLabel, sourceFile, quantity
    }

    // Tolerant decode so older saved jobs (without newer fields) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        slot = (try? c.decode(Int.self, forKey: .slot)) ?? 0
        detectedType = (try? c.decode(String.self, forKey: .detectedType)) ?? ""
        detectedColorHex = (try? c.decode(String.self, forKey: .detectedColorHex)) ?? "#888888"
        grams = (try? c.decode(Double.self, forKey: .grams)) ?? 0
        matchedFilamentID = try? c.decode(UUID.self, forKey: .matchedFilamentID)
        pricePerKg = (try? c.decode(Double.self, forKey: .pricePerKg)) ?? 0
        isPurge = (try? c.decode(Bool.self, forKey: .isPurge)) ?? false
        filamentLabel = try? c.decode(String.self, forKey: .filamentLabel)
        sourceFile = try? c.decode(String.self, forKey: .sourceFile)
        quantity = (try? c.decode(Int.self, forKey: .quantity)) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(slot, forKey: .slot)
        try c.encode(detectedType, forKey: .detectedType)
        try c.encode(detectedColorHex, forKey: .detectedColorHex)
        try c.encode(grams, forKey: .grams)
        try c.encode(matchedFilamentID, forKey: .matchedFilamentID)
        try c.encode(pricePerKg, forKey: .pricePerKg)
        try c.encode(isPurge, forKey: .isPurge)
        try c.encode(filamentLabel, forKey: .filamentLabel)
        try c.encode(sourceFile, forKey: .sourceFile)
        try c.encode(quantity, forKey: .quantity)
    }
}

/// A saved calculation (history record snapshot). One entry per order.
struct Job: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var fileName: String
    var plateName: String
    var printerID: UUID?
    var printerName: String
    var printSeconds: Double
    var lines: [FilamentLine]
    var laborCost: Double
    var failPercent: Double
    var markupPercent: Double
    var electricityPricePerKWh: Double
    var powerWatts: Double
    var depreciationPerHour: Double
    var breakdown: CostBreakdown
    var files: [JobFile]? = nil   // per-file editable structure (multi-file orders)
}

/// One file within a saved order, kept so the order can be re-opened and fully edited.
struct JobFile: Codable, Hashable {
    var fileName: String
    var printSeconds: Double
    var quantity: Int
    var lines: [FilamentLine]   // per-unit (quantity 1); JobFile.quantity holds the multiplier
    var previewPNG: Data? = nil // cached small plate render, so old quotes still show an image
}
