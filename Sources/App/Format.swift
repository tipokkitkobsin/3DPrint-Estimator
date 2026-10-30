import Foundation

/// Display formatting helpers.
enum Fmt {
    static func money(_ value: Double, _ symbol: String) -> String {
        "\(symbol) " + String(format: "%.2f", value)
    }
    static func moneyWhole(_ value: Double, _ symbol: String) -> String {
        "\(symbol) " + String(format: "%.0f", value.rounded())
    }
    static func grams(_ value: Double) -> String { String(format: "%.1f g", value) }
    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}
