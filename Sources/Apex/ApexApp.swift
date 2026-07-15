import SwiftUI

// MARK: - ApexApp
//
// App entry. Dark-first by design (DESIGN_PRINCIPLES §3).
//
// Start state via APEX_START env ("empty" | "demo" | "live" | "recording") so
// CI / the snapshot harness can render any screen deterministically. Real first
// run is "empty" (the designed invitation). "recording" boots straight into the
// live recording screen driven by a SimulatedLocationProvider primed with a
// partial track — so CI captures a mid-ride screenshot with no GPS.

@main
struct ApexApp: App {
    private let start: String
    private let store: RideStore

    init() {
        let start = ProcessInfo.processInfo.environment["APEX_START"] ?? "empty"
        self.start = start
        let mode: RideStore.Mode
        switch start {
        case "demo", "recording": mode = .demo
        case "live": mode = .live
        default: mode = .empty
        }
        store = RideStore(mode: mode)
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, start: start)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - RootView
//
// Hosts the library and presents the recording screen. Owns the live-vs-
// simulated location provider choice.

struct RootView: View {
    @State var store: RideStore
    let start: String
    @State private var showRecording = false

    var body: some View {
        RideLibraryView(store: store, onRecord: { showRecording = true })
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView(
                    session: makeSession(),
                    onFinish: { ride in
                        if let ride { store.add(ride) }
                        showRecording = false
                    },
                    onClose: { showRecording = false }
                )
                .preferredColorScheme(.dark)
            }
            .onAppear {
                // CI/demo: boot straight into a mid-ride recording screenshot.
                if start == "recording" { showRecording = true }
            }
    }

    private func makeSession() -> RecordingSession {
        #if targetEnvironment(simulator)
        let simulated = true
        #else
        // Demo mode or the CI "recording" state use the simulated provider so no
        // GPS/permission is needed; a real install uses live GPS.
        let simulated = (start == "recording" || start == "demo")
        #endif

        if simulated {
            let provider = SimulatedLocationProvider()
            let session = RecordingSession(provider: provider)
            if start == "recording" {
                // Frozen, time-coherent partial ride for a deterministic CI/demo
                // screenshot (distance & clock reconcile; no live timer/GPS).
                let track = SampleData.rides[2].samples
                let partial = Array(track.prefix(max(2, track.count * 2 / 5)))
                session.loadPreview(partial)
            }
            return session
        } else {
            return RecordingSession(provider: CLLocationProvider())
        }
    }
}
