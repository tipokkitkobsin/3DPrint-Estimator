import SwiftUI
import AppKit

/// A plate render thumbnail. Reserves its space so cards never shift when an image is missing.
struct PlateThumb: View {
    let plate: PlateData
    var size: CGFloat = 64
    var onTap: (() -> Void)? = nil

    private var image: NSImage? {
        guard let d = plate.preview ?? plate.previewSmall else { return nil }
        return NSImage(data: d)
    }

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "cube.transparent")
                    .font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.25)))
        .contentShape(Rectangle())
        .onTapGesture { if image != nil { onTap?() } }
        .help(plate.name)
        .accessibilityLabel("Preview of \(plate.name)")
    }
}

/// Click-to-enlarge view of a plate render.
struct PlatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plate: PlateData

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(plate.name).font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            if let d = plate.preview ?? plate.previewSmall, let img = NSImage(data: d) {
                Image(nsImage: img)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 560, maxHeight: 540)
            } else {
                Text("No preview available").foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 620, height: 620)
    }
}
