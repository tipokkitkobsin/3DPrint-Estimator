import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case calculate = "Calculate"
    case history = "History"
    case filaments = "Filaments"
    case printers = "Printers"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .calculate: return "function"
        case .history: return "clock.arrow.circlepath"
        case .filaments: return "swatchpalette"
        case .printers: return "printer"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedTab) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon).tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .listStyle(.sidebar)
        } detail: {
            switch store.selectedTab {
            case .calculate: CalculateView()
            case .history: HistoryView()
            case .filaments: FilamentsView()
            case .printers: PrintersView()
            case .settings: SettingsView()
            }
        }
        .onChange(of: store.pendingOpenURL) { _, url in
            if let url {
                store.addFiles([url])
                store.selectedTab = .calculate
                store.pendingOpenURL = nil
            }
        }
    }
}
