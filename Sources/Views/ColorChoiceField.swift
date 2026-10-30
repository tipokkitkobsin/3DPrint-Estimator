import SwiftUI

/// A named filament color. Picking one sets both the friendly name and the hex swatch.
struct ColorChoice: Hashable {
    let name: String
    let hex: String
}

enum ColorPresets {
    static let all: [ColorChoice] = [
        ColorChoice(name: "White",       hex: "#FFFFFF"),
        ColorChoice(name: "Black",       hex: "#1A1A1A"),
        ColorChoice(name: "Gray",        hex: "#808080"),
        ColorChoice(name: "Silver",      hex: "#C0C0C0"),
        ColorChoice(name: "Red",         hex: "#E03B3B"),
        ColorChoice(name: "Orange",      hex: "#F5821F"),
        ColorChoice(name: "Yellow",      hex: "#F2C200"),
        ColorChoice(name: "Green",       hex: "#2ECC71"),
        ColorChoice(name: "Blue",        hex: "#1E90FF"),
        ColorChoice(name: "Cyan",        hex: "#20C4D9"),
        ColorChoice(name: "Purple",      hex: "#8E44AD"),
        ColorChoice(name: "Pink",        hex: "#FF6FB5"),
        ColorChoice(name: "Brown",       hex: "#8B5A2B"),
        ColorChoice(name: "Gold",        hex: "#D4AF37"),
        ColorChoice(name: "Beige",       hex: "#E8D8B0"),
        ColorChoice(name: "Natural",     hex: "#EDE8DD")
    ]

    static func match(hex: String) -> ColorChoice? {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}

/// Pick a named color, "Any color" (no specific color — matches any), or Custom…
/// An empty colorName means "any color": the entry matches every color of its material.
struct ColorChoiceField: View {
    @Binding var colorName: String
    @Binding var colorHex: String

    @State private var isCustom: Bool

    private let noneTag = "\u{2063}none"
    private let customTag = "\u{2063}custom"

    init(colorName: Binding<String>, colorHex: Binding<String>) {
        self._colorName = colorName
        self._colorHex = colorHex
        let isNone = colorName.wrappedValue.isEmpty
        let isPreset = ColorPresets.match(hex: colorHex.wrappedValue) != nil
        self._isCustom = State(initialValue: !isNone && !isPreset)
    }

    var body: some View {
        HStack {
            Picker("Color", selection: selectionBinding) {
                Text("Any color (same for all)").tag(noneTag)
                Divider()
                ForEach(ColorPresets.all, id: \.hex) { c in
                    Text(c.name).tag(c.hex)
                }
                Text("Custom…").tag(customTag)
            }
            swatch
        }
        if isCustom {
            ColorPicker("Custom color", selection: colorBinding, supportsOpacity: false)
            TextField("Color name", text: $colorName)
        }
    }

    @ViewBuilder private var swatch: some View {
        if colorName.isEmpty && !isCustom {
            Image(systemName: "circle.dashed")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        } else {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.secondary.opacity(0.35)))
        }
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: {
                if isCustom { return customTag }
                if colorName.isEmpty { return noneTag }
                return ColorPresets.match(hex: colorHex)?.hex ?? customTag
            },
            set: { sel in
                if sel == noneTag {
                    isCustom = false
                    colorName = ""
                    colorHex = "#CCCCCC"
                } else if sel == customTag {
                    isCustom = true
                } else if let c = ColorPresets.all.first(where: { $0.hex == sel }) {
                    isCustom = false
                    colorName = c.name
                    colorHex = c.hex
                }
            }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) },
            set: { colorHex = $0.toHex() }
        )
    }
}
