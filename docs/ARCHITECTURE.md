# Apex — Architecture

Technical principles and structure. This serves `DESIGN_PRINCIPLES.md`: the
architecture exists to make a beautiful, correct, verifiable app cheap to evolve.

---

## 1. Stack

- **Language:** Swift 6.3 (`swift-6.3-RELEASE`), strict concurrency on.
- **UI:** SwiftUI, iOS 17+ target (SwiftData, `MapKit` SwiftUI `Map`, Observation).
- **Persistence:** SwiftData (`@Model`) — rides + samples stored locally, offline-first.
- **Location:** CoreLocation with background updates (recording a ride while the
  screen is off / app backgrounded). `allowsBackgroundLocationUpdates`.
- **Maps:** MapKit (SwiftUI `Map`, `MapPolyline`), dark-styled per DESIGN_SYSTEM §7.
- **Build/deploy from Linux:** `xtool` (no Mac in the loop). See AGENTS.md.

No third-party UI frameworks. The design system is ours; dependencies are a
liability for a design-led app.

---

## 2. Architecture principles

**A1 — Feature-first, MV, no over-abstraction.** SwiftUI + Observation + SwiftData
already give us a clean view-model story. Use `@Observable` store objects for
stateful concerns (recording session, ride library); keep pure views dumb and
driven by tokens + data. Don't import a VIPER/TCA-scale ceremony for a 2-feature
app — but DO keep side-effecting logic (location, persistence) out of views.

**A2 — The design system is a layer, not a suggestion.** `DesignSystem/Theme.swift`
is the only place literals live. Views compose tokens. This is what makes
Transit-level polish maintainable: restyle once, everywhere updates.

**A3 — Everything visual is previewable headless.** Every screen must render from
**seeded sample data** with zero live dependencies (no GPS, no real location
permission) so it can be screenshotted in CI and viewed. Live data is injected at
the app root; previews/harness inject `SampleData`. (This is non-negotiable — it's
how we SEE the UI without a Mac.)

**A4 — Correct numbers are a unit-tested contract.** Distance (Haversine over
samples), duration (moving vs elapsed), speed, elevation gain — all live in pure,
testable functions in `RideMetrics`, not scattered in views. Trophy stats (P4)
get tests with known inputs/outputs.

**A5 — Location is abstracted behind a protocol.** `LocationProviding` protocol
with a real `CLLocationManager` impl and a `SimulatedLocationProvider` (plays back
a GPX track) so recording UI can be exercised without motion — in CI and on a
stationary desk.

---

## 3. Module layout

```
Sources/Apex/
  ApexApp.swift              // @main App, root, model container, DI
  DesignSystem/
    Theme.swift              // ALL tokens (color/type/space/motion) — SoT
    Components/              // reusable styled atoms: ApexCard, StatBlock,
                             //   PrimaryButton, RouteThumbnail, Pill, ...
  Features/
    RideLibrary/             // saved rides list (FIRST screen we build)
      RideLibraryView.swift
      RideCardView.swift
    RideDetail/              // one ride, full map + stats
    Recording/              // live recording screen
  Model/
    Ride.swift               // @Model: id, startedAt, samples, title, notes
    RideSample.swift         // @Model: lat, lon, altitude, speed, timestamp
    RideMetrics.swift        // pure stat computations (tested)
  Services/
    LocationProviding.swift  // protocol + CLLocationManager impl + simulated
    RideStore.swift          // @Observable library CRUD over SwiftData
  Support/
    SampleData.swift         // seeded, realistic rides for previews/CI/harness
    GPX.swift                // parse a .gpx track (for simulated provider + demo)
Tools/
  SnapshotHarness/           // headless render target (see §4)
Tests/
  ApexTests/                 // RideMetrics correctness, route-color determinism
```

---

## 4. Verification architecture (how we SEE it — two tiers)

Per the earlier hard-won lesson, the macOS CI simulator loop works but is
**slow and high-variance** (~3.5–5.5 min, dominated by simulator lifecycle). So:

**Tier 1 — Snapshot render harness (FAST, primary during design).**
A tiny target that uses SwiftUI `ImageRenderer` to render a specific screen (fed
`SampleData`) straight to a PNG — **no simulator boot at all**. Runs on macOS CI
in seconds, not minutes. This is the loop we use for rapid UI iteration. It is the
concrete payoff of the "leave the sim lifecycle behind" conclusion from the probe
work.
- Harness takes a screen id + device size, renders at `@3x`, writes PNG.
- CI uploads PNGs as artifacts; the agent downloads and *views* them.

**Tier 2 — Full simulator screenshot (SLOWER, for truth).**
The proven `simctl` path: build for `arm64-apple-ios-simulator`, boot, install,
launch, `simctl io screenshot`. Higher fidelity (real UIKit compositing,
real Map tiles, real blur) but slow/noisy. Run this for final verification of a
screen and for anything the harness can't render faithfully (live MapKit tiles).

CI lessons already banked (baked into `screenshot.yml`, do not relearn):
- ❌ Never boot a simulator concurrently with `brew install` — they contend, brew
  goes 22s→200s+. Boot serially, after install+build.
- ❌ Never cache the Homebrew cask — warm cache makes brew skip linking →
  `xtool: command not found`. Cold brew is only ~11s; don't cache it.
- ✅ Poll for a rendered frame (size threshold) instead of `sleep`.

---

## 5. Data model (first cut)

```
Ride
  id: UUID
  title: String            // auto ("Morning Ride") or user-set
  startedAt: Date
  endedAt: Date
  samples: [RideSample]    // ordered GPS track
  notes: String?
  // derived (computed via RideMetrics, not stored unless perf demands):
  //   distance, movingDuration, elapsedDuration, topSpeed, avgSpeed, elevGain

RideSample
  timestamp: Date
  latitude / longitude: Double
  altitude: Double
  speed: Double            // m/s, -1 if unknown
  horizontalAccuracy: Double
```

Route identity color is derived from `ride.id` (deterministic, DESIGN_SYSTEM
§route-color) — not stored, always recomputed, always stable.

---

## 6. Privacy & the CarPlay principle

- Location data never leaves the device. No account, no cloud, no analytics in v1.
- Background location is used ONLY while a ride is actively recording, and the
  recording state is always visibly indicated.
- Apex never grabs the audio session or interrupts playback unless the rider
  explicitly enables an experimental "silence on connect" toggle (parked; the
  supported fix is a Shortcuts automation — documented for the user). Principle
  P5: quiet until it matters.

---

## 7. Non-goals (v1)

- No social feed, no cloud sync, no accounts.
- No turn-by-turn navigation (Apex records and celebrates rides; it doesn't route).
- No Android. No iPad-optimized layout yet (iPhone-first).
