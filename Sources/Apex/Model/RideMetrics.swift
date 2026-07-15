import Foundation
import CoreLocation

// MARK: - RideMetrics
//
// Pure, testable computations for a ride's "trophy" stats (Principle P4).
// No UI, no side effects. Unit-tested in Tests/ApexTests with known inputs.
// Views read these; they never compute stats inline.

public enum RideMetrics {

    /// Total distance in meters (sum of Haversine hops over the track).
    public static func distanceMeters(_ samples: [RideSample]) -> Double {
        guard samples.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<samples.count {
            total += haversine(samples[i - 1], samples[i])
        }
        return total
    }

    /// Elapsed wall-clock duration (end - start).
    public static func elapsedDuration(_ ride: Ride) -> TimeInterval {
        ride.endedAt.timeIntervalSince(ride.startedAt)
    }

    /// Moving duration: time where speed indicates motion (> 0.5 m/s ~ 1.8 km/h).
    public static func movingDuration(_ samples: [RideSample]) -> TimeInterval {
        guard samples.count > 1 else { return 0 }
        var moving = 0.0
        for i in 1..<samples.count {
            let dt = samples[i].timestamp.timeIntervalSince(samples[i - 1].timestamp)
            let s = samples[i].speed >= 0
                ? samples[i].speed
                : haversine(samples[i - 1], samples[i]) / max(dt, 0.001)
            if s > 0.5 { moving += dt }
        }
        return moving
    }

    /// Top speed in m/s. Uses recorded speed where present, else derives it.
    public static func topSpeedMetersPerSec(_ samples: [RideSample]) -> Double {
        guard samples.count > 1 else { return 0 }
        var top = 0.0
        for i in 1..<samples.count {
            let dt = samples[i].timestamp.timeIntervalSince(samples[i - 1].timestamp)
            let s = samples[i].speed >= 0
                ? samples[i].speed
                : haversine(samples[i - 1], samples[i]) / max(dt, 0.001)
            top = max(top, s)
        }
        return top
    }

    /// Average moving speed in m/s (distance / moving time).
    public static func avgSpeedMetersPerSec(_ samples: [RideSample]) -> Double {
        let moving = movingDuration(samples)
        guard moving > 0 else { return 0 }
        return distanceMeters(samples) / moving
    }

    /// Total elevation gain in meters (sum of positive altitude deltas).
    public static func elevationGainMeters(_ samples: [RideSample]) -> Double {
        guard samples.count > 1 else { return 0 }
        var gain = 0.0
        for i in 1..<samples.count {
            let d = samples[i].altitude - samples[i - 1].altitude
            if d > 0 { gain += d }
        }
        return gain
    }

    /// Number of corners carved — the app's signature stat (tagline: "Keep every
    /// corner"). A corner is a sustained directional change of at least
    /// `minTurnDegrees` accumulated along the track. We deliberately count the
    /// ROAD's character, not speed, so the trophy rewards a twisty ride rather
    /// than a fast one.
    ///
    /// Algorithm: thin the track to ~`minSegmentMeters` spacing (so dense GPS
    /// jitter doesn't inflate the count), walk the bearing between consecutive
    /// kept points, and accumulate signed turn. A reversal of direction starts a
    /// fresh accumulation; whenever the running turn reaches the threshold we
    /// count one corner and reset. This maps closely to how a rider would count
    /// "corners" — one per meaningful bend, ignoring straight-line wobble.
    public static func cornerCount(
        _ samples: [RideSample],
        minTurnDegrees: Double = 30,
        minSegmentMeters: Double = 8
    ) -> Int {
        guard samples.count >= 3 else { return 0 }

        // Thin to meaningful spacing.
        var kept: [RideSample] = [samples[0]]
        for s in samples.dropFirst() {
            if haversine(kept[kept.count - 1], s) >= minSegmentMeters { kept.append(s) }
        }
        guard kept.count >= 3 else { return 0 }

        // Bearings between consecutive kept points.
        var bearings: [Double] = []
        bearings.reserveCapacity(kept.count - 1)
        for i in 1..<kept.count { bearings.append(bearing(kept[i - 1], kept[i])) }

        var corners = 0
        var accum = 0.0
        for i in 1..<bearings.count {
            var d = bearings[i] - bearings[i - 1]
            while d > 180 { d -= 360 }
            while d < -180 { d += 360 }
            // If direction reverses, begin a new corner accumulation.
            if accum != 0 && (d > 0) != (accum > 0) {
                accum = d
            } else {
                accum += d
            }
            if abs(accum) >= minTurnDegrees {
                corners += 1
                accum = 0
            }
        }
        return corners
    }

    /// Initial bearing from a to b, in degrees (0 = north, clockwise).
    static func bearing(_ a: RideSample, _ b: RideSample) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    // MARK: Haversine

    /// Great-circle distance between two samples, in meters.
    static func haversine(_ a: RideSample, _ b: RideSample) -> Double {
        let R = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * R * asin(min(1, sqrt(h)))
    }
}

// MARK: - Formatting
//
// Presentation helpers. Keep unit formatting in one place so every screen shows
// stats identically. Metric-first (rider is in a metric locale by context here);
// a real app would honor Locale — parked as a v1.1 nicety.

public enum RideFormat {

    public static func distance(_ meters: Double) -> String {
        let km = meters / 1000
        if km < 10 { return String(format: "%.1f", km) }
        return String(format: "%.0f", km)
    }

    public static let distanceUnit = "km"

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// h:mm:ss for the live recording timer (monospaced digits in UI).
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    public static func speed(_ metersPerSec: Double) -> String {
        String(format: "%.0f", metersPerSec * 3.6)   // km/h
    }

    public static let speedUnit = "km/h"

    public static func elevation(_ meters: Double) -> String {
        String(format: "%.0f", meters)
    }

    public static let elevationUnit = "m"

    /// Short relative day label, e.g. "Today", "Yesterday", "Mon 14".
    public static func dayLabel(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            f.dateFormat = "EEEE"          // Monday
        } else {
            f.dateFormat = "EEE d MMM"     // Mon 14 Jul
        }
        return f.string(from: date)
    }

    public static func timeOfDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
