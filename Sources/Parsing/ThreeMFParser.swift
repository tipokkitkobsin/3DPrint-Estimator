import Foundation

/// Reads a Bambu .3mf (project or sliced): slice_info.config for cost data,
/// plus the embedded plate PNG renders for preview.
enum ThreeMFParser {
    static func parse(url: URL) -> SliceData {
        let name = url.lastPathComponent
        guard let xml = extractEntry(zip: url, entry: "Metadata/slice_info.config"), !xml.isEmpty else {
            return SliceData(fileName: name,
                             plates: [PlateData(name: "Plate 1", printSeconds: 0, slots: [])],
                             isSliced: false,
                             note: "This .3mf has no slice info — slice it in Bambu Studio, or enter values manually.")
        }
        let parsed = SliceInfoXML.parse(data: xml)
        let plates = parsed.map { p -> PlateData in
            var q = p
            q.preview = extractEntry(zip: url, entry: "Metadata/plate_\(p.index).png")
            q.previewSmall = extractEntry(zip: url, entry: "Metadata/plate_\(p.index)_small.png")
            return q
        }
        let hasData = plates.contains { $0.printSeconds > 0 || !$0.slots.isEmpty }
        if !hasData {
            return SliceData(fileName: name,
                             plates: plates.isEmpty ? [PlateData(name: "Plate 1", printSeconds: 0, slots: [])] : plates,
                             isSliced: false,
                             note: "This .3mf appears unsliced — enter values manually or slice first.")
        }
        return SliceData(fileName: name, plates: plates, isSliced: true, note: nil)
    }

    /// Extracts a single zip entry to memory using /usr/bin/unzip (always present on macOS).
    static func extractEntry(zip: URL, entry: String) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-p", zip.path, entry]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return data.isEmpty ? nil : data
    }
}

/// XML delegate that reads <plate> blocks from slice_info.config.
final class SliceInfoXML: NSObject, XMLParserDelegate {
    static func parse(data: Data) -> [PlateData] {
        let d = SliceInfoXML()
        let parser = XMLParser(data: data)
        parser.delegate = d
        parser.parse()
        return d.plates
    }

    private(set) var plates: [PlateData] = []
    private var inPlate = false
    private var curName = "Plate"
    private var curIndex = 1
    private var curSeconds: Double = 0
    private var curSlots: [SlotData] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "plate":
            inPlate = true; curName = "Plate"; curSeconds = 0; curSlots = []
            curIndex = plates.count + 1
        case "metadata":
            guard inPlate, let key = attributeDict["key"], let value = attributeDict["value"] else { return }
            if key == "index" {
                curName = "Plate \(value)"
                curIndex = Int(value) ?? (plates.count + 1)
            }
            if key == "prediction" { curSeconds = Double(value) ?? 0 }
        case "filament":
            guard inPlate else { return }
            let slot = Int(attributeDict["id"] ?? "") ?? (curSlots.count + 1)
            let type = attributeDict["type"] ?? "PLA"
            let color = GcodeParser.normalizeHex(attributeDict["color"] ?? "#888888")
            let usedG = Double(attributeDict["used_g"] ?? "0") ?? 0
            let usedMM = (Double(attributeDict["used_m"] ?? "0") ?? 0) * 1000.0
            if usedG > 0 || usedMM > 0 {
                curSlots.append(SlotData(slot: slot, type: type, colorHex: color, grams: usedG, lengthMM: usedMM))
            }
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "plate" {
            plates.append(PlateData(name: curName, printSeconds: curSeconds, slots: curSlots, index: curIndex))
            inPlate = false
        }
    }
}
