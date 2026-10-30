# 3DPrint Estimator

A native macOS app that reads sliced Bambu Studio files (`.gcode`, `.gcode.3mf`,
`.3mf`) and calculates the cost and selling price of a print.

## Build / rebuild

    ./build.sh

Produces `build/3DPrint Estimator.app`. Requires the Xcode Command Line Tools
(Swift 6+). No full Xcode or Apple Developer account needed.

First launch: right-click the app → **Open** once to get past Gatekeeper
(it is ad-hoc signed for personal use).

## What it does

- Drop a sliced file (or use Open / Finder "Open With") → auto-fills print
  time and per-slot filament grams. Every value stays editable; unsliced
  `.3mf` files load with blank numbers you fill in by hand.
- Multi-color (per AMS slot) and multi-plate (plate picker) supported.
- Cost = Material + Energy + Machine depreciation + Labor, then Fail markup,
  then Profit markup (markup-on-cost). Fail% and Markup% have global defaults
  (Settings) and per-job sliders.
- Filament library, printer profiles, job history, and quote export
  (PDF + copy-to-clipboard).
- All data stored locally in `~/Library/Application Support/PrintCostCalc/data.json`.

## Source layout

    Sources/Models    data types (Filament, PrinterProfile, AppSettings, Job)
    Sources/Parsing   gcode + 3mf (slice_info.config) parsers
    Sources/Cost      pure cost-calculation engine
    Sources/App       app entry, persistence store, formatting
    Sources/Views     SwiftUI screens (Calculate, History, Filaments, Printers, Settings)

## License

MIT. See `LICENSE`.

Not affiliated with or endorsed by Bambu Lab. "Bambu Lab" and "Bambu Studio" are
trademarks of their owners.
