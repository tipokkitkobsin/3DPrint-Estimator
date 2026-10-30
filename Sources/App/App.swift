import SwiftUI
import AppKit

@main
struct PrintCostCalcApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 940, minHeight: 620)
                .onAppear {
                    if let u = OpenFileBus.drain() { store.pendingOpenURL = u }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openPrintFile)) { note in
                    if let url = note.object as? URL { store.pendingOpenURL = url }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

extension Notification.Name {
    static let openPrintFile = Notification.Name("io.github.tipokkitkobsin.printcostcalc.openFile")
}

/// Buffers files opened at cold launch (before the window subscribes).
enum OpenFileBus {
    static var buffer: [URL] = []
    static func drain() -> URL? {
        let last = buffer.last
        buffer.removeAll()
        return last
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        let supported = urls.filter { FileImporter.isSupported($0) }
        OpenFileBus.buffer.append(contentsOf: supported)
        for u in supported {
            NotificationCenter.default.post(name: .openPrintFile, object: u)
        }
    }
}
