import Foundation
import CoreLocation

// MARK: - LocationProviding
//
// The seam between the recording UI and where GPS fixes come from. The recording
// screen depends ONLY on this protocol, never on CLLocationManager directly.
// That gives us two interchangeable sources:
//   • CLLocationProvider        — real GPS on device (production).
//   • SimulatedLocationProvider — replays a track (CI, demo, stationary desk).
//
// This is what makes the recording screen verifiable in CI (no GPS there) while
// working with real GPS on the phone by swapping one injected dependency.

public protocol LocationProviding: AnyObject {
    /// Called for each new fix while recording.
    var onSample: ((RideSample) -> Void)? { get set }
    /// Called when authorization state changes (so UI can prompt/explain).
    var onAuthChange: ((LocationAuth) -> Void)? { get set }

    var auth: LocationAuth { get }

    /// Ask the user for permission (no-op for the simulator).
    func requestAuthorization()
    /// Begin emitting samples.
    func start()
    /// Stop emitting samples.
    func stop()
}

public enum LocationAuth: Equatable, Sendable {
    case notDetermined
    case denied
    case authorizedWhenInUse
    case authorizedAlways
    /// Simulator: always "ready" so demo/CI never blocks on a permission prompt.
    case simulated
}

// MARK: - CLLocationProvider (real GPS)
//
// Production location source. Configured for riding: best accuracy, background
// updates so a ride keeps recording with the screen off. Emits RideSample per
// CLLocation fix. Not used in CI (no GPS) — used on the installed app.

public final class CLLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    public var onSample: ((RideSample) -> Void)?
    public var onAuthChange: ((LocationAuth) -> Void)?

    private let manager = CLLocationManager()

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .otherNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        // Only enable background updates once we hold "Always"/"WhenInUse" — set
        // at start() to avoid a crash if the plist mode is ever missing.
        manager.pausesLocationUpdatesAutomatically = false
    }

    public var auth: LocationAuth {
        Self.map(manager.authorizationStatus)
    }

    public func requestAuthorization() {
        // Ask for WhenInUse first; we escalate to Always contextually if needed.
        manager.requestWhenInUseAuthorization()
    }

    public func start() {
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
    }

    public func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    // MARK: CLLocationManagerDelegate

    public func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        for loc in locs where loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 50 {
            onSample?(RideSample(
                timestamp: loc.timestamp,
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                speed: loc.speed >= 0 ? loc.speed : -1
            ))
        }
    }

    public func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        onAuthChange?(Self.map(m.authorizationStatus))
    }

    private static func map(_ s: CLAuthorizationStatus) -> LocationAuth {
        switch s {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorizedWhenInUse: return .authorizedWhenInUse
        case .authorizedAlways: return .authorizedAlways
        @unknown default: return .notDetermined
        }
    }
}

// MARK: - SimulatedLocationProvider (playback)
//
// Replays an existing sample track at an accelerated pace, emitting the SAME
// RideSample stream a real ride would. Used by CI and Demo Mode so the recording
// screen renders a live-looking ride with no GPS and no permission prompt.

public final class SimulatedLocationProvider: LocationProviding {
    public var onSample: ((RideSample) -> Void)?
    public var onAuthChange: ((LocationAuth) -> Void)?

    public let auth: LocationAuth = .simulated

    private let track: [RideSample]
    private var index = 0
    private var timer: Timer?
    private let interval: TimeInterval

    /// - Parameters:
    ///   - track: the source track to replay (defaults to a sample ride).
    ///   - interval: seconds between emitted samples (fast-forwarded pace).
    public init(track: [RideSample] = SampleData.rides[2].samples, interval: TimeInterval = 0.25) {
        self.track = track
        self.interval = interval
    }

    public func requestAuthorization() { onAuthChange?(.simulated) }

    public func start() {
        index = 0
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard self.index < self.track.count else { self.stop(); return }
            // Re-stamp to "now" so live duration counts from record start.
            let src = self.track[self.index]
            self.onSample?(RideSample(
                timestamp: Date(),
                latitude: src.latitude,
                longitude: src.longitude,
                altitude: src.altitude,
                speed: src.speed
            ))
            self.index += 1
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Emit the first `n` samples synchronously with time-coherent timestamps —
    /// used for a deterministic CI screenshot (a partially-recorded ride) without
    /// waiting on a timer. Samples are back-dated using their ORIGINAL relative
    /// spacing and ending "now", so the recorded distance and the elapsed clock
    /// reconcile (no "1.9 km in 3 seconds" artifact).
    public func prime(_ n: Int) {
        let count = min(n, track.count)
        guard count > 1 else { return }
        let now = Date()
        let originStart = track[0].timestamp
        let originEnd = track[count - 1].timestamp
        let span = max(originEnd.timeIntervalSince(originStart), 1)
        for i in 0..<count {
            let src = track[i]
            let frac = src.timestamp.timeIntervalSince(originStart) / span
            // Map the original timeline onto [now - span, now].
            let ts = now.addingTimeInterval(-span + frac * span)
            onSample?(RideSample(
                timestamp: ts,
                latitude: src.latitude,
                longitude: src.longitude,
                altitude: src.altitude,
                speed: src.speed
            ))
        }
        index = count
    }
}
