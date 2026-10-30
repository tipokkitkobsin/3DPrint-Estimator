import Foundation

/// Immutable result of a cost calculation.
struct CostBreakdown: Codable, Hashable {
    var material: Double
    var energy: Double
    var machine: Double
    var labor: Double
    var base: Double          // material + energy + machine + labor
    var failMarkup: Double     // base * fail%
    var cost: Double           // base + failMarkup  (true cost incl. expected waste)
    var markupAmount: Double    // cost * markup%
    var finalPrice: Double      // cost + markupAmount
}

/// Pure cost math. No mutation, no side effects.
enum CostCalculator {
    static func breakdown(lines: [FilamentLine],
                          printSeconds: Double,
                          powerWatts: Double,
                          electricityPricePerKWh: Double,
                          depreciationPerHour: Double,
                          laborCost: Double,
                          failPercent: Double,
                          markupPercent: Double) -> CostBreakdown {
        let hours = max(printSeconds, 0) / 3600.0
        let material = lines.reduce(0.0) { $0 + $1.lineCost }
        let energy = hours * (powerWatts / 1000.0) * electricityPricePerKWh
        let machine = hours * depreciationPerHour
        let labor = laborCost
        let base = material + energy + machine + labor
        let failMarkup = base * (failPercent / 100.0)
        let cost = base + failMarkup
        let markupAmount = cost * (markupPercent / 100.0)
        let finalPrice = cost + markupAmount
        return CostBreakdown(material: material, energy: energy, machine: machine,
                             labor: labor, base: base, failMarkup: failMarkup,
                             cost: cost, markupAmount: markupAmount, finalPrice: finalPrice)
    }
}
