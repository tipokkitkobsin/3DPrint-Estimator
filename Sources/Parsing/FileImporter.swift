import Foundation

/// Routes a dropped/opened file to the right parser based on extension.
enum FileImporter {
    static let supportedExtensions = ["gcode", "3mf"]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func load(url: URL) -> SliceData {
        let ext = url.pathExtension.lowercased()
        if ext == "3mf" {
            return ThreeMFParser.parse(url: url)   // covers .gcode.3mf and project .3mf
        }
        let text = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
            ?? ""
        return GcodeParser.parse(text: text, fileName: url.lastPathComponent)
    }
}
