import XCTest
@testable import Apex
import Foundation

final class RideMetricsTests: XCTestCase {

    // Two points ~1 km apart on the equator → Haversine ≈ 1000 m (±1%).
    func testHaversineKnownDistance() {
        let a = RideSample(timestamp: Date(), latitude: 0, longitude: 0, altitude: 0, speed: -1)
        // 0.008983 deg lon at equator ≈ 1000 m
        let b = RideSample(timestamp: Date(), latitude: 0, longitude: 0.008983, altitude: 0, speed: -1)
        let d = RideMetrics.haversine(a, b)
        XCTAssertEqual(d, 1000, accuracy: 10)
    }

    func testDistanceSumsHops() {
        let t = Date()
        let s = [
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 0, speed: -1),
            RideSample(timestamp: t, latitude: 0, longitude: 0.008983, altitude: 0, speed: -1),
            RideSample(timestamp: t, latitude: 0, longitude: 0.017966, altitude: 0, speed: -1),
        ]
        XCTAssertEqual(RideMetrics.distanceMeters(s), 2000, accuracy: 25)
    }

    func testDistanceEmptyAndSingle() {
        XCTAssertEqual(RideMetrics.distanceMeters([]), 0)
        let one = [RideSample(timestamp: Date(), latitude: 1, longitude: 1, altitude: 0, speed: 0)]
        XCTAssertEqual(RideMetrics.distanceMeters(one), 0)
    }

    func testElevationGainCountsOnlyPositive() {
        let t = Date()
        let s = [
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 100, speed: 0),
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 150, speed: 0), // +50
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 120, speed: 0), // -30 ignored
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 170, speed: 0), // +50
        ]
        XCTAssertEqual(RideMetrics.elevationGainMeters(s), 100, accuracy: 0.001)
    }

    func testTopSpeedUsesRecordedSpeed() {
        let t = Date()
        let s = [
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 0, speed: 10),
            RideSample(timestamp: t.addingTimeInterval(1), latitude: 0, longitude: 0, altitude: 0, speed: 30),
            RideSample(timestamp: t.addingTimeInterval(2), latitude: 0, longitude: 0, altitude: 0, speed: 20),
        ]
        XCTAssertEqual(RideMetrics.topSpeedMetersPerSec(s), 30, accuracy: 0.001)
    }

    func testMovingDurationExcludesStops() {
        let t = Date()
        let s = [
            RideSample(timestamp: t, latitude: 0, longitude: 0, altitude: 0, speed: 0),
            RideSample(timestamp: t.addingTimeInterval(10), latitude: 0, longitude: 0, altitude: 0, speed: 0),   // stopped 10s
            RideSample(timestamp: t.addingTimeInterval(20), latitude: 0, longitude: 0, altitude: 0, speed: 15),  // moving 10s
        ]
        XCTAssertEqual(RideMetrics.movingDuration(s), 10, accuracy: 0.001)
    }

    // MARK: Corners

    /// A dead-straight line has zero corners.
    func testCornerCountStraightLineIsZero() {
        let t = Date()
        // ~10 points marching due east, ~20 m apart, no turns.
        var s: [RideSample] = []
        for i in 0..<10 {
            s.append(RideSample(timestamp: t, latitude: 0,
                                longitude: Double(i) * 0.00018, altitude: 0, speed: 10))
        }
        XCTAssertEqual(RideMetrics.cornerCount(s), 0)
    }

    /// A single ~90° bend (east, then north) counts as exactly one corner.
    func testCornerCountSingleRightAngle() {
        let t = Date()
        var s: [RideSample] = []
        // Leg 1: due east (well over the 8 m thinning threshold per hop).
        for i in 0..<6 {
            s.append(RideSample(timestamp: t, latitude: 0,
                                longitude: Double(i) * 0.00018, altitude: 0, speed: 10))
        }
        // Leg 2: due north from the corner point.
        let lon = 5 * 0.00018
        for i in 1..<6 {
            s.append(RideSample(timestamp: t, latitude: Double(i) * 0.00018,
                                longitude: lon, altitude: 0, speed: 10))
        }
        XCTAssertEqual(RideMetrics.cornerCount(s), 1)
    }

    /// Corners must be deterministic — same track in, same count out.
    func testCornerCountDeterministic() {
        let ride = SampleData.rides[0]
        let a = RideMetrics.cornerCount(ride.samples)
        let b = RideMetrics.cornerCount(ride.samples)
        XCTAssertEqual(a, b)
        // Sanity: a real twisty sample ride has a meaningful, non-trivial count.
        XCTAssertGreaterThan(a, 3)
    }
}

final class RouteColorTests: XCTestCase {
    // Determinism: same id → same color, different ids → (almost always) different.
    func testRouteColorDeterministic() {
        let c1 = Theme.routeColor(for: "ride-abc")
        let c2 = Theme.routeColor(for: "ride-abc")
        XCTAssertEqual(c1, c2)
    }

    func testSampleRidesGetDistinctColors() {
        let colors = SampleData.rides.map { Theme.routeColor(for: $0.id) }
        // No two adjacent sample rides should collide to the same hue.
        let unique = Set(colors.map { "\($0)" })
        XCTAssertEqual(unique.count, colors.count)
    }
}

final class RideFormatTests: XCTestCase {
    func testDistanceFormatting() {
        XCTAssertEqual(RideFormat.distance(5400), "5.4")   // < 10 km → 1 decimal
        XCTAssertEqual(RideFormat.distance(41000), "41")   // ≥ 10 km → integer
    }

    func testDurationFormatting() {
        XCTAssertEqual(RideFormat.duration(38 * 60), "38m")
        XCTAssertEqual(RideFormat.duration(122 * 60), "2h 2m")
    }

    func testClockFormatting() {
        XCTAssertEqual(RideFormat.clock(3661), "1:01:01")
    }
}

// MARK: - Crash-safe journal (background-termination recovery)

final class RideJournalTests: XCTestCase {
    private func tempJournal() -> (RideJournal, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apex-journal-test-\(UUID().uuidString)")
        return (RideJournal(directory: dir), dir)
    }

    private func sample(_ i: Int) -> RideSample {
        RideSample(timestamp: Date(timeIntervalSince1970: 1_000 + Double(i)),
                   latitude: 35.5 + Double(i) * 0.001,
                   longitude: -83.9 - Double(i) * 0.001,
                   altitude: 500 + Double(i), speed: 10 + Double(i))
    }

    /// A journaled ride is fully recoverable after an (unfinished) session.
    func testRecoversJournaledRide() {
        let (j, dir) = tempJournal()
        defer { try? FileManager.default.removeItem(at: dir) }

        j.begin(rideID: "ride-x", title: "Test Ride", startedAt: Date(timeIntervalSince1970: 1_000))
        for i in 0..<10 { j.append(sample(i)) }
        j.flush()   // drain async writes before reading back
        // NOTE: no finish() → simulates a background termination mid-ride.

        XCTAssertTrue(j.hasInterruptedRide())
        let recovered = j.recoverRide()
        XCTAssertNotNil(recovered)
        XCTAssertEqual(recovered?.id, "ride-x")
        XCTAssertEqual(recovered?.title, "Test Ride")
        XCTAssertEqual(recovered?.samples.count, 10)
        XCTAssertEqual(recovered?.samples.first?.latitude ?? 0, 35.5, accuracy: 1e-9)
    }

    /// finish() clears the journal so no stale recovery is offered.
    func testFinishClearsJournal() {
        let (j, dir) = tempJournal()
        defer { try? FileManager.default.removeItem(at: dir) }
        j.begin(rideID: "ride-y", title: "T", startedAt: Date())
        j.append(sample(0)); j.append(sample(1))
        j.finish()
        XCTAssertFalse(j.hasInterruptedRide())
        XCTAssertNil(j.recoverRide())
    }

    /// A torn final line (killed mid-write) is skipped; the rest still recovers.
    func testTornLastLineIsSkipped() {
        let (j, dir) = tempJournal()
        defer { try? FileManager.default.removeItem(at: dir) }
        j.begin(rideID: "ride-z", title: "T", startedAt: Date(timeIntervalSince1970: 1_000))
        for i in 0..<5 { j.append(sample(i)) }
        j.flush()   // ensure the 5 good lines are on disk before we tear the file
        // Append a garbage half-written line directly to the file.
        let file = dir.appendingPathComponent("ride-in-progress.jsonl")
        if let h = try? FileHandle(forWritingTo: file) {
            h.seekToEndOfFile()
            h.write(Data("{\"t\":1005,\"la\":35.5,\"lo\":-8".utf8))  // torn, no newline/close
            try? h.close()
        }
        let recovered = j.recoverRide()
        XCTAssertNotNil(recovered)
        XCTAssertEqual(recovered?.samples.count, 5)   // torn line skipped, 5 good ones kept
    }
}
