import Foundation

/// Parses Bambu/Orca-style G-code header comments for time and per-slot filament usage.
enum GcodeParser {
    static func parse(text: String, fileName: String) -> SliceData {
        var seconds: Double = 0
        var grams: [Double] = []
        var lengthsMM: [Double] = []
        var types: [String] = []
        var colors: [String] = []

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(";") else { continue }
            let lower = line.lowercased()

            if let r = lower.range(of: "estimated time:", options: .backwards),
               let t = parseDuration(String(lower[r.upperBound...])) {
                seconds = max(seconds, t)
            }
            if lower.contains("filament used [mm]") {
                lengthsMM = numberList(afterEquals(line))
            }
            if lower.contains("filament used [g]"), !lower.contains("total") {
                grams = numberList(afterEquals(line))
            } else if grams.isEmpty, lower.contains("total filament used [g]") {
                grams = numberList(afterEquals(line))
            }
            if lower.contains("filament_type") {
                types = stringList(afterEquals(line))
            }
            if lower.contains("filament_colour") || lower.contains("filament_color") {
                colors = stringList(afterEquals(line))
            }
        }

        let count = max(grams.count, max(types.count, max(colors.count, lengthsMM.count)))
        var slots: [SlotData] = []
        for i in 0..<count {
            let g = i < grams.count ? grams[i] : 0
            let ln = i < lengthsMM.count ? lengthsMM[i] : 0
            if g <= 0 && ln <= 0 { continue }
            let ty = i < types.count ? types[i] : "PLA"
            let co = i < colors.count ? normalizeHex(colors[i]) : "#888888"
            slots.append(SlotData(slot: i + 1, type: ty, colorHex: co, grams: g, lengthMM: ln))
        }

        let sliced = seconds > 0 || !slots.isEmpty
        let plate = PlateData(name: "Plate 1", printSeconds: seconds, slots: slots)
        return SliceData(fileName: fileName, plates: [plate], isSliced: sliced,
                         note: sliced ? nil : "No slice estimates found — enter values manually or slice in Bambu Studio.")
    }

    // MARK: - Helpers

    static func afterEquals(_ s: String) -> String {
        if let r = s.range(of: "=") { return String(s[r.upperBound...]) }
        if let r = s.range(of: ":") { return String(s[r.upperBound...]) }
        return ""
    }

    static func numberList(_ s: String) -> [Double] {
        s.split(whereSeparator: { $0 == "," || $0 == ";" })
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    static func stringList(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Parses "1d 2h 5m 12s", "1h 5m", "45m", "90s" etc. into seconds.
    static func parseDuration(_ s: String) -> Double? {
        var total: Double = 0
        var found = false
        var number = ""
        for ch in s {
            if ch.isNumber || ch == "." {
                number.append(ch)
            } else if let unit = unitSeconds(ch), let n = Double(number) {
                total += n * unit
                found = true
                number = ""
            } else {
                number = ""
            }
        }
        return found ? total : nil
    }

    private static func unitSeconds(_ ch: Character) -> Double? {
        switch ch {
        case "d": return 86400
        case "h": return 3600
        case "m": return 60
        case "s": return 1
        default: return nil
        }
    }

    static func normalizeHex(_ s: String) -> String {
        var c = s.uppercased()
        if !c.hasPrefix("#") { c = "#" + c }
        if c.count == 9 { c = String(c.prefix(7)) }   // strip alpha #RRGGBBAA
        return c
    }
}
