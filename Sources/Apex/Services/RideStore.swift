import SwiftUI
import Observation

// MARK: - RideStore
//
// The single source of truth for what rides the app shows and which mode it's
// in. Three modes:
//   • .empty — no rides yet (first run). Shows the designed empty state (U7).
//   • .demo  — seeded SampleData rides so the app can be explored with NO real
//              data. This is "Demo Mode": try the whole experience before your
//              first ride. Fully reversible (Exit Demo → back to empty).
//   • .live  — the user's real recorded rides (SwiftData-backed; wired later).
//
// Keeping mode here (not in views) means every screen reacts to it and demo mode
// is a first-class, testable state — not a debug hack.

@Observable
public final class RideStore {

    public enum Mode: Equatable, Sendable {
        case empty
        case demo
        case live
    }

    public private(set) var mode: Mode
    public private(set) var rides: [Ride]

    public init(mode: Mode = .empty) {
        self.mode = mode
        self.rides = RideStore.rides(for: mode, live: [])
    }

    /// Real rides come from persistence in .live; injected here later.
    private var liveRides: [Ride] = []

    public var isDemo: Bool { mode == .demo }
    public var hasRides: Bool { !rides.isEmpty }

    // MARK: Mode transitions

    /// Enter demo mode — populate with seeded sample rides.
    public func enterDemo() {
        mode = .demo
        rides = SampleData.rides
    }

    /// Leave demo mode — return to whatever real state exists.
    public func exitDemo() {
        mode = liveRides.isEmpty ? .empty : .live
        rides = liveRides
    }

    /// Called when real rides load/change (from SwiftData, later).
    public func setLiveRides(_ newRides: [Ride]) {
        liveRides = newRides
        if mode != .demo {
            mode = newRides.isEmpty ? .empty : .live
            rides = newRides
        }
    }

    private static func rides(for mode: Mode, live: [Ride]) -> [Ride] {
        switch mode {
        case .empty: return []
        case .demo:  return SampleData.rides
        case .live:  return live
        }
    }
}
