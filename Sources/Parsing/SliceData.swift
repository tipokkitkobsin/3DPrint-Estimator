import Foundation

/// One filament slot's usage as read from a slice file.
struct SlotData: Identifiable, Hashable {
    var id = UUID()
    var slot: Int
    var type: String
    var colorHex: String
    var grams: Double
    var lengthMM: Double
}

/// One build plate, including Bambu's embedded render previews.
struct PlateData: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var printSeconds: Double
    var slots: [SlotData]
    var index: Int = 1
    var preview: Data? = nil        // Metadata/plate_N.png (full render)
    var previewSmall: Data? = nil   // Metadata/plate_N_small.png (cached in saved jobs)
}

/// The parsed result of a dropped file.
struct SliceData {
    var fileName: String
    var plates: [PlateData]
    var isSliced: Bool
    var note: String?
}
