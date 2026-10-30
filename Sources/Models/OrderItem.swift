import Foundation

/// Sentinel plate index meaning "combine all plates".
let allPlatesTag = -1

/// One uploaded file in the order, with its own plate choice, time, lines, and print count.
struct OrderItem: Identifiable {
    let id = UUID()
    var slice: SliceData
    var plateIndex: Int
    var printSeconds: Double
    var lines: [FilamentLine]
    var quantity: Int = 1
}
