import Foundation

/// A spool of filament in the user's library.
/// Identity is brand + material + variant + a friendly color name (hex is just for the swatch).
struct Filament: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var brand: String          // "Bambu Lab", "Polymaker", "Generic", or custom
    var type: String           // base material, e.g. "PLA"
    var variant: String        // "", "Silk", "Silk+", "Dual Silk", "Pro", "HT", ...
    var colorName: String      // friendly name, e.g. "Galaxy Blue"
    var pricePerKg: Double
    var colorHex: String       // "#RRGGBB" for the swatch
    var density: Double        // g/cm^3, used only if a file reports length instead of weight

    /// Material with its variant suffix, e.g. "PLA Silk".
    var materialLabel: String {
        variant.isEmpty ? type : "\(type) \(variant)"
    }

    /// Full library label, e.g. "Bambu Lab PLA Silk — Galaxy Blue".
    var displayName: String {
        let base = "\(brand) \(materialLabel)".trimmingCharacters(in: .whitespaces)
        return colorName.isEmpty ? base : "\(base) — \(colorName)"
    }

    init(id: UUID = UUID(), brand: String = "Generic", type: String, variant: String = "",
         colorName: String = "", pricePerKg: Double, colorHex: String = "#888888", density: Double = 1.24) {
        self.id = id
        self.brand = brand
        self.type = type
        self.variant = variant
        self.colorName = colorName
        self.pricePerKg = pricePerKg
        self.colorHex = colorHex
        self.density = density
    }

    // Tolerant Codable so older data.json (which used "name") still loads.
    enum CodingKeys: String, CodingKey {
        case id, brand, type, variant, colorName, name, pricePerKg, colorHex, density
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        brand = (try? c.decode(String.self, forKey: .brand)) ?? "Generic"
        type = (try? c.decode(String.self, forKey: .type)) ?? "PLA"
        variant = (try? c.decode(String.self, forKey: .variant)) ?? ""
        colorName = (try? c.decode(String.self, forKey: .colorName))
            ?? (try? c.decode(String.self, forKey: .name)) ?? ""
        pricePerKg = (try? c.decode(Double.self, forKey: .pricePerKg)) ?? 0
        colorHex = (try? c.decode(String.self, forKey: .colorHex)) ?? "#888888"
        density = (try? c.decode(Double.self, forKey: .density)) ?? 1.24
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(brand, forKey: .brand)
        try c.encode(type, forKey: .type)
        try c.encode(variant, forKey: .variant)
        try c.encode(colorName, forKey: .colorName)
        try c.encode(pricePerKg, forKey: .pricePerKg)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(density, forKey: .density)
    }
}

/// Suggested presets used by the editor's combo fields.
enum FilamentPresets {
    static let brands = ["Bambu Lab", "Polymaker", "Generic"]
    static let materials = ["PLA", "PETG", "ABS", "ASA", "TPU", "PA", "PC", "PVA", "PLA-CF", "PETG-CF", "PA-CF"]
    static let variants = ["", "Basic", "Matte", "Silk", "Silk+", "Dual Silk", "Pro", "HT", "Tough", "High Speed", "Glow", "Marble"]
}

/// A printer the user owns. Holds the per-machine numbers that are NOT in the slice file.
struct PrinterProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var powerWatts: Double
    var purchasePrice: Double
    var lifetimeHours: Double
    var useCustomElectricity: Bool = false
    var electricityPricePerKWh: Double = 4.5

    var depreciationPerHour: Double {
        lifetimeHours > 0 ? purchasePrice / lifetimeHours : 0
    }
}

/// Global, user-editable defaults.
struct AppSettings: Codable {
    var currencySymbol: String = "฿"
    var electricityPricePerKWh: Double = 4.5
    var defaultFailPercent: Double = 10
    var defaultMarkupPercent: Double = 50
    var defaultLaborCost: Double = 0
    var defaultPrinterID: UUID? = nil
}
