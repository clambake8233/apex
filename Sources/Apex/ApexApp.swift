import SwiftUI

// MARK: - ApexApp
//
// App entry. Dark-first by design (DESIGN_PRINCIPLES §3).
//
// Initial state is EMPTY on a real first run — the rider sees the designed
// invitation (EmptyLibraryView) with "Try Demo Mode". The starting mode can be
// overridden via the APEX_START launch env var ("empty" | "demo" | "live") so
// CI/the snapshot harness can render any state deterministically. This keeps the
// real default honest while making every state verifiable.

@main
struct ApexApp: App {
    private let store: RideStore

    init() {
        let start = ProcessInfo.processInfo.environment["APEX_START"] ?? "empty"
        let mode: RideStore.Mode
        switch start {
        case "demo": mode = .demo
        case "live": mode = .live
        default:     mode = .empty
        }
        store = RideStore(mode: mode)
    }

    var body: some Scene {
        WindowGroup {
            RideLibraryView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}
