import AppKit
import UniformTypeIdentifiers

/// Builds a plain-text quote and renders it to PDF or PNG; also copies text to clipboard.
enum QuoteExporter {
    static func text(job: Job, symbol: String) -> String {
        var out = "3D PRINT COST QUOTE\n"
        out += String(repeating: "=", count: 44) + "\n"
        out += "File:    \(job.fileName)\n"
        out += "Plate:   \(job.plateName)\n"
        out += "Date:    \(Fmt.date(job.date))\n"
        out += "Printer: \(job.printerName)\n"
        out += "Time:    \(Fmt.duration(job.printSeconds))\n\n"

        // Group by source file so multi-file orders read as an itemized bill.
        var order: [String] = []
        var seen = Set<String>()
        for l in job.lines {
            let f = l.sourceFile ?? ""
            if !seen.contains(f) { seen.insert(f); order.append(f) }
        }
        let multi = order.count > 1
        out += "MATERIALS\n"
        for f in order {
            let group = job.lines.filter { ($0.sourceFile ?? "") == f }
            let fileQty = group.first?.quantity ?? 1
            if multi && !f.isEmpty {
                out += "\n  \u{2022} \(f)" + (fileQty > 1 ? "  \u{00D7}\(fileQty)" : "") + "\n"
            }
            for l in group {
                let label = l.isPurge ? "Purge / waste" : "Slot \(l.slot)"
                let indent = multi && !f.isEmpty ? "    " : "  "
                out += "\(indent)\(label) — \(l.displaySpec)\n"
                let qtyStr = l.quantity > 1 ? " \u{00D7} \(l.quantity)" : ""
                out += "\(indent)    \(Fmt.grams(l.grams))\(qtyStr) @ \(Fmt.money(l.pricePerKg, symbol))/kg = \(Fmt.money(l.lineCost, symbol))\n"
            }
            if multi && !f.isEmpty {
                let sub = group.reduce(0.0) { $0 + $1.lineCost }
                out += "      File material: \(Fmt.money(sub, symbol))\n"
            }
        }

        let b = job.breakdown
        out += "\n"
        out += row("Material", b.material, symbol)
        out += row("Energy", b.energy, symbol)
        out += row("Machine", b.machine, symbol)
        out += row("Labor", b.labor, symbol)
        out += row("Subtotal", b.base, symbol)
        out += row("Fail (\(Int(job.failPercent))%)", b.failMarkup, symbol)
        out += row("Cost", b.cost, symbol)
        out += row("Markup (\(Int(job.markupPercent))%)", b.markupAmount, symbol)
        out += String(repeating: "-", count: 44) + "\n"
        out += "FINAL PRICE: \(Fmt.moneyWhole(b.finalPrice, symbol))\n"
        return out
    }

    private static func row(_ label: String, _ value: Double, _ symbol: String) -> String {
        "  \(label.padding(toLength: 22, withPad: " ", startingAt: 0)) \(Fmt.money(value, symbol))\n"
    }

    // MARK: - Clipboard

    static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Rendering

    private static func makeTextView(_ text: String, image: Data? = nil) -> NSTextView {
        var scaled: NSImage?
        var imageHeight: CGFloat = 0
        if let d = image, let img = NSImage(data: d), img.size.width > 0 {
            let maxW: CGFloat = 220
            let scale = min(1, maxW / img.size.width)
            let target = NSSize(width: img.size.width * scale, height: img.size.height * scale)
            let resized = NSImage(size: target)
            resized.lockFocus()
            img.draw(in: NSRect(origin: .zero, size: target))
            resized.unlockFocus()
            scaled = resized
            imageHeight = target.height + 24
        }
        let lineCount = text.components(separatedBy: "\n").count
        let height = max(CGFloat(lineCount) * 16 + 64 + imageHeight, 240)
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 560, height: height))
        tv.isEditable = false
        tv.drawsBackground = true
        tv.backgroundColor = .white
        tv.textContainerInset = NSSize(width: 24, height: 24)

        let attr = NSMutableAttributedString()
        if let simg = scaled {
            let att = NSTextAttachment()
            att.attachmentCell = NSTextAttachmentCell(imageCell: simg)
            attr.append(NSAttributedString(attachment: att))
            attr.append(NSAttributedString(string: "\n\n"))
        }
        attr.append(NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.black
        ]))
        tv.textStorage?.setAttributedString(attr)
        return tv
    }

    private static func jobPreview(_ job: Job) -> Data? {
        job.files?.compactMap { $0.previewPNG }.first
    }

    static func pdfData(_ text: String, image: Data? = nil) -> Data {
        let tv = makeTextView(text, image: image)
        return tv.dataWithPDF(inside: tv.bounds)
    }

    static func pngData(_ text: String, image: Data? = nil) -> Data {
        let tv = makeTextView(text, image: image)
        guard let rep = tv.bitmapImageRepForCachingDisplay(in: tv.bounds) else { return Data() }
        tv.cacheDisplay(in: tv.bounds, to: rep)
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    // MARK: - Save

    static func savePDF(job: Job, symbol: String) {
        save(pdfData(text(job: job, symbol: symbol), image: jobPreview(job)), name: quoteName(job) + ".pdf", type: .pdf)
    }

    static func savePNG(job: Job, symbol: String) {
        save(pngData(text(job: job, symbol: symbol), image: jobPreview(job)), name: quoteName(job) + ".png", type: .png)
    }

    private static func save(_ data: Data, name: String, type: UTType) {
        guard !data.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    /// Quote-<base> with the slice extension stripped (.gcode.3mf, .gcode, .3mf).
    private static func quoteName(_ job: Job) -> String {
        var base = job.fileName
        for ext in [".gcode.3mf", ".gcode", ".3mf"] where base.lowercased().hasSuffix(ext) {
            base = String(base.dropLast(ext.count))
            break
        }
        return "Quote-\(base)"
    }
}
