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
        case "demo", "recording", "detail": mode = .demo
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
    @State private var showDetail = false

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
            .fullScreenCover(isPresented: $showDetail) {
                RideDetailView(ride: SampleData.rides[0], onClose: { showDetail = false })
                    .preferredColorScheme(.dark)
            }
            .onAppear {
                // CI/demo: boot straight into a mid-ride recording screenshot,
                // or the ride-detail screen, for deterministic renders.
                if start == "recording" { showRecording = true }
                if start == "detail" { showDetail = true }
                // Real launch: if a previous session was terminated mid-ride (e.g.
                // iOS reclaimed memory while navigating in another app), recover
                // that ride from the crash-safe journal so it isn't lost.
                if start != "recording" && start != "demo" && start != "detail" {
                    recoverInterruptedRideIfAny()
                }
            }
    }

    /// Recover a ride left behind by a background termination, save it, clear the
    /// journal. A silent auto-save is the kind, rider-first behavior (P3/P5): the
    /// ride simply shows up in the garage rather than nagging with a dialog.
    private func recoverInterruptedRideIfAny() {
        let journal = RideJournal.shared
        guard journal.hasInterruptedRide(), let ride = journal.recoverRide() else { return }
        store.add(ride)
        journal.finish()
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
            // No journal for CI/demo — the simulated provider must never touch disk
            // or trigger crash-recovery. Real GPS sessions get the crash-safe journal.
            let session = RecordingSession(provider: provider, journal: nil)
            if start == "recording" {
                // Frozen, time-coherent partial ride for a deterministic CI/demo
                // screenshot. Uses REAL road geometry (Tail of the Dragon) so the
                // route sits on an actual road over the MapKit base — not a random
                // walk that drifts across water. Distance & clock reconcile by
                // construction (no live timer/GPS).
                session.loadPreview(RecordingPreviewTrack.samples)
            }
            return session
        } else {
            return RecordingSession(provider: CLLocationProvider())
        }
    }
}
