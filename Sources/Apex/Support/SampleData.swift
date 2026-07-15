import Foundation
import CoreLocation

// MARK: - SampleData
//
// Realistic seeded rides for previews, the snapshot harness, and CI.
// Per ARCHITECTURE A3: every screen renders from this with zero live deps.
// Tracks are synthesized to look like real twisty motorcycle roads (not a
// straight line) so rendered screenshots reflect what a rider actually sees.

public enum SampleData {

    public static let rides: [Ride] = [
        makeRide(
            id: "ride-tail-of-the-dragon",
            title: "Tail of the Dragon",
            daysAgo: 0, startHour: 8, minutes: 47,
            center: (35.5540, -83.9540),
            windiness: 1.0, spanKm: 17, climb: 380, topKmh: 92, seed: 11
        ),
        makeRide(
            id: "ride-coast-run",
            title: "Pacific Coast Run",
            daysAgo: 1, startHour: 16, minutes: 122,
            center: (36.2704, -121.8081),
            windiness: 0.55, spanKm: 74, climb: 610, topKmh: 118, seed: 29
        ),
        makeRide(
            id: "ride-canyon-loop",
            title: "Canyon Loop",
            daysAgo: 4, startHour: 7, minutes: 64,
            center: (34.0954, -118.7360),
            windiness: 0.8, spanKm: 41, climb: 520, topKmh: 104, seed: 47
        ),
        makeRide(
            id: "ride-sunday-blast-1",
            title: "Sunday Morning Blast",
            daysAgo: 9, startHour: 9, minutes: 38,
            center: (40.0470, -105.3720),
            windiness: 0.9, spanKm: 23, climb: 300, topKmh: 88, seed: 63
        ),
        makeRide(
            id: "ride-alpine-pass",
            title: "Alpine Pass",
            daysAgo: 16, startHour: 10, minutes: 96,
            center: (46.5197, 7.9660),
            windiness: 1.0, spanKm: 58, climb: 1240, topKmh: 97, seed: 82
        ),
    ]

    public static var newest: Ride { rides[0] }

    // MARK: Synthesis

    /// Build a ride with a plausible winding track and realistic stats.
    static func makeRide(
        id: String,
        title: String,
        daysAgo: Int,
        startHour: Int,
        minutes: Int,
        center: (Double, Double),
        windiness: Double,     // 0 = gentle, 1 = very twisty
        spanKm: Double,        // rough end-to-end distance
        climb: Double,         // target elevation gain (m)
        topKmh: Double,        // target top speed
        seed: UInt64
    ) -> Ride {
        var rng = SplitMix64(seed: seed)

        let start = referenceDate(daysAgo: daysAgo, hour: startHour)
        let end = start.addingTimeInterval(Double(minutes) * 60)

        let count = max(40, minutes * 3)   // ~one sample / 20s
        var samples: [RideSample] = []
        samples.reserveCapacity(count)

        // Walk a heading with correlated random turns → smooth serpentine path.
        var lat = center.0
        var lon = center.1
        var heading = rng.nextUnit() * 2 * .pi
        let stepMeters = (spanKm * 1000) / Double(count)
        let metersPerDegLat = 111_320.0

        // Altitude as ROLLING TERRAIN, not a ramp. Real roads rise and fall — a
        // pass has valleys on the way up. We sum a few low-frequency sine "octaves"
        // (big hills + finer relief) at jittered frequency/phase, over a modest net
        // climb, so the elevation profile shows genuine peaks AND dips while still
        // netting out to a believable positive gain. Deterministic per seed.
        let baseAltitude = 300 + rng.nextUnit() * 400
        let reliefAmp = climb * 0.5
        let netClimb = climb * 0.5
        struct Octave { let f: Double; let phase: Double; let amp: Double }
        let octaves: [Octave] = [(1.1, 1.0), (2.2, 0.45), (3.6, 0.18)].map { base, amp in
            Octave(f: base * (0.85 + rng.nextUnit() * 0.3),
                   phase: rng.nextUnit() * 2 * .pi,
                   amp: amp)
        }
        func rawAltitude(_ t: Double) -> Double {
            let relief = octaves.reduce(0.0) { $0 + $1.amp * sin(t * .pi * 2 * $1.f + $1.phase) }
            return baseAltitude + netClimb * t + reliefAmp * relief * 0.5
        }
        // Pre-compute + lightly smooth (kills tiny sawtooth, keeps the hills).
        var rawAlts = (0..<count).map { rawAltitude(Double($0) / Double(count - 1)) }
        if count >= 3 {
            var smoothed = rawAlts
            for i in 0..<count {
                let lo = max(0, i - 1), hi = min(count - 1, i + 1)
                smoothed[i] = (rawAlts[lo] + rawAlts[i] + rawAlts[hi]) / 3
            }
            rawAlts = smoothed
        }

        for i in 0..<count {
            let t = Double(i) / Double(count)
            // Turn amount scales with windiness; correlated (river-like meander).
            let turn = (rng.nextUnit() - 0.5) * windiness * 0.9
            heading += turn

            let dLat = (stepMeters * cos(heading)) / metersPerDegLat
            let dLon = (stepMeters * sin(heading)) / (metersPerDegLat * cos(lat * .pi / 180))
            lat += dLat
            lon += dLon

            // Speed profile: accelerate out, cruise, ease at the very end, with a
            // couple of realistic near-stops (junction/photo) so moving time < elapsed.
            let base = topKmh * (0.45 + 0.5 * sin(.pi * min(1, t * 1.05)))
            let jitter = (rng.nextUnit() - 0.5) * 14
            var kmh = max(6, min(topKmh, base + jitter))
            // Occasional brief stop (~1 in 22 samples): speed drops to ~0.
            if rng.nextUnit() < 0.045 { kmh = rng.nextUnit() * 3 }
            let speed = kmh / 3.6

            let altitude = max(5, rawAlts[i])

            let ts = start.addingTimeInterval(Double(i) / Double(count - 1) * Double(minutes) * 60)
            samples.append(RideSample(
                timestamp: ts,
                latitude: lat,
                longitude: lon,
                altitude: altitude,
                speed: speed
            ))
        }

        return Ride(id: id, title: title, startedAt: start, endedAt: end, samples: samples)
    }

    /// A fixed reference "now" so seeded rides render identically every run
    /// (deterministic screenshots). Anchored to a Wednesday morning.
    static func referenceNow() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 15
        c.hour = 11; c.minute = 30
        return Calendar.current.date(from: c) ?? Date()
    }

    static func referenceDate(daysAgo: Int, hour: Int) -> Date {
        let base = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: referenceNow()
        ) ?? referenceNow()
        return Calendar.current.date(
            bySettingHour: hour, minute: 0, second: 0, of: base
        ) ?? base
    }
}

// MARK: - Deterministic RNG (SplitMix64)

/// Tiny deterministic PRNG so sample tracks are identical across runs → stable,
/// diffable screenshots.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
