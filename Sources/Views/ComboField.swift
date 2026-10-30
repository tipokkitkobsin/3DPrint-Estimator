import SwiftUI

/// A picker of preset strings with an "Other…" escape hatch that reveals a text field.
/// Reused for brand and variant so the user gets suggestions but can type anything.
struct ComboField: View {
    let title: String
    @Binding var value: String
    let options: [String]

    @State private var isCustom: Bool

    private let customTag = "\u{2063}__custom__"

    init(title: String, value: Binding<String>, options: [String]) {
        self.title = title
        self._value = value
        self.options = options
        self._isCustom = State(initialValue: !options.contains(value.wrappedValue))
    }

    var body: some View {
        Picker(title, selection: pickerBinding) {
            ForEach(options, id: \.self) { opt in
                Text(opt.isEmpty ? "(none)" : opt).tag(opt)
            }
            Text("Other…").tag(customTag)
        }
        if isCustom {
            TextField("Custom \(title.lowercased())", text: $value)
        }
    }

    private var pickerBinding: Binding<String> {
        Binding(
            get: { isCustom ? customTag : value },
            set: { sel in
                if sel == customTag {
                    isCustom = true
                    value = ""
                } else {
                    isCustom = false
                    value = sel
                }
            }
        )
    }
}
