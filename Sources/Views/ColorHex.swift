import SwiftUI
import AppKit

extension Color {
    /// Creates a Color from a "#RRGGBB" string; falls back to gray.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = .gray
            return
        }
        self = Color(.sRGB,
                     red: Double((v >> 16) & 0xFF) / 255.0,
                     green: Double((v >> 8) & 0xFF) / 255.0,
                     blue: Double(v & 0xFF) / 255.0)
    }

    /// Converts to "#RRGGBB" via sRGB.
    func toHex() -> String {
        let ns = (NSColor(self).usingColorSpace(.sRGB)) ?? NSColor(self)
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
