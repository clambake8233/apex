import Foundation
import CoreLocation

// MARK: - Ride
//
// A recorded motorcycle ride. In v1 this is a plain value type seeded from
// SampleData for UI development; it will be promoted to a SwiftData @Model once
// the library screen is verified. Keeping it a struct now means the whole UI
// renders headless (no persistence stack) for the fast snapshot harness.

public struct Ride: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var startedAt: Date
    public var endedAt: Date
    public var samples: [RideSample]
    public var notes: String?

    public init(
        id: String,
        title: String,
        startedAt: Date,
        endedAt: Date,
        samples: [RideSample],
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.samples = samples
        self.notes = notes
    }
}

// MARK: - RideSample

public struct RideSample: Hashable, Sendable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var speed: Double            // m/s, -1 if unknown

    public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        speed: Double
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
