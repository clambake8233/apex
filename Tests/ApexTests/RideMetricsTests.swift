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
