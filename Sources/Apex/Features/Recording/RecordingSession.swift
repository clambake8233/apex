import Foundation
import SwiftUI
import Observation

// MARK: - RecordingSession
//
// The @Observable state machine behind the recording screen. Consumes a
// LocationProviding stream, accumulates RideSamples, and exposes LIVE stats
// (distance, elapsed, current + top speed) that the UI binds to. On finish it
// produces a completed Ride ready to hand to RideStore/persistence.
//
// It is source-agnostic: inject CLLocationProvider on device, or
// SimulatedLocationProvider in CI/demo. The UI never knows the difference.

@Observable
public final class RecordingSession {

    public enum State: Equatable, Sendable {
        case idle
        case requestingPermission
        case recording
        case paused
        case finished
    }

    // MARK: Observable state
    public private(set) var state: State = .idle
    public private(set) var samples: [RideSample] = []
    public private(set) var startedAt: Date?

    // Live stats (recomputed as samples arrive).
    public private(set) var distanceMeters: Double = 0
    public private(set) var currentSpeed: Double = 0     // m/s
    public private(set) var topSpeed: Double = 0         // m/s
    public private(set) var elapsed: TimeInterval = 0

    public var auth: LocationAuth { provider.auth }

    // MARK: Dependencies
    private let provider: LocationProviding
    private var ticker: Timer?
    private var pausedAccumulated: TimeInterval = 0
    private var lastResumeAt: Date?

    public init(provider: LocationProviding) {
        self.provider = provider
        self.provider.onSample = { [weak self] sample in
            self?.ingest(sample)
        }
    }

    // MARK: Control

    public func startOrRequest() {
        switch provider.auth {
        case .notDetermined:
            state = .requestingPermission
            provider.onAuthChange = { [weak self] a in
                guard let self else { return }
                if a == .authorizedWhenInUse || a == .authorizedAlways || a == .simulated {
                    self.beginRecording()
                } else if a == .denied {
                    self.state = .idle
                }
            }
            provider.requestAuthorization()
        case .denied:
            state = .idle   // UI shows a "enable location in Settings" hint
        default:
            beginRecording()
        }
    }

    private func beginRecording() {
        startedAt = Date()
        lastResumeAt = Date()
        pausedAccumulated = 0
        samples.removeAll()
        distanceMeters = 0; currentSpeed = 0; topSpeed = 0; elapsed = 0
        state = .recording
        provider.start()
        startTicker()
    }

    public func pause() {
        guard state == .recording else { return }
        accumulateElapsed()
        lastResumeAt = nil
        provider.stop()
        ticker?.invalidate()
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        lastResumeAt = Date()
        provider.start()
        startTicker()
        state = .recording
    }

    /// Stop and produce a completed Ride (nil if too short to be meaningful).
    @discardableResult
    public func finish() -> Ride? {
        accumulateElapsed()
        provider.stop()
        ticker?.invalidate()
        state = .finished
        guard samples.count > 1, let start = startedAt else { return nil }
        return Ride(
            id: "ride-\(UUID().uuidString)",
            title: Self.autoTitle(for: start),
            startedAt: start,
            endedAt: Date(),
            samples: samples
        )
    }

    // MARK: Ingestion

    private func ingest(_ s: RideSample) {
        if let last = samples.last {
            distanceMeters += RideMetrics.haversine(last, s)
        }
        samples.append(s)
        let spd = s.speed >= 0 ? s.speed : 0
        currentSpeed = spd
        topSpeed = max(topSpeed, spd)
    }

    // MARK: Elapsed timekeeping

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let resume = self.lastResumeAt else { return }
            self.elapsed = self.pausedAccumulated + Date().timeIntervalSince(resume)
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func accumulateElapsed() {
        if let resume = lastResumeAt {
            pausedAccumulated += Date().timeIntervalSince(resume)
            elapsed = pausedAccumulated
        }
    }

    // MARK: Helpers

    /// A friendly auto title based on the start time of day.
    static func autoTitle(for date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case 5..<11:  return "Morning Ride"
        case 11..<14: return "Midday Ride"
        case 14..<18: return "Afternoon Ride"
        case 18..<22: return "Evening Ride"
        default:      return "Night Ride"
        }
    }

    // MARK: Preview (CI / demo)

    /// Load a FROZEN, time-coherent recording snapshot for screenshots/previews —
    /// no live timer, no GPS. Elapsed is derived from the samples' own timespan so
    /// distance and clock reconcile (a real partial ride, paused in time).
    public func loadPreview(_ preview: [RideSample]) {
        guard preview.count > 1 else { return }
        samples = preview
        startedAt = preview.first?.timestamp
        distanceMeters = RideMetrics.distanceMeters(preview)
        elapsed = preview.last!.timestamp.timeIntervalSince(preview.first!.timestamp)
        currentSpeed = preview.last!.speed >= 0 ? preview.last!.speed : 0
        topSpeed = RideMetrics.topSpeedMetersPerSec(preview)
        state = .recording
    }
}
