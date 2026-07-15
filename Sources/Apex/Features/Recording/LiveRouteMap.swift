import SwiftUI
import MapKit

// MARK: - FollowMode
//
// How the live map tracks the rider (P3: predictable, glanceable while moving).
//   • followRoute — DEFAULT. Keeps the rider's DRAWN route (their keepsake) in
//     frame while following them as the ride grows. North-up so the route reads
//     naturally; frames a bounded trailing window so a long ride never shrinks
//     the route to a dot. This is the "record & keep every corner" view: your
//     route stays the hero, and you never lose your current position.
//   • headingUp — nav-style. The rider is pinned near the lower third and the map
//     ROTATES so the road AHEAD is always "up". Best for reading what's coming;
//     the already-ridden route recedes behind you.
//   • northUp — pinned follow at a fixed zoom, north always up (no rotation). A
//     direction chevron on the marker keeps travel direction readable.
public enum FollowMode: String, CaseIterable, Sendable {
    case followRoute
    case headingUp
    case northUp

    var next: FollowMode {
        switch self {
        case .followRoute: return .headingUp
        case .headingUp:   return .northUp
        case .northUp:     return .followRoute
        }
    }

    var iconName: String {
        switch self {
        case .followRoute: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .headingUp:   return "location.north.line.fill"
        case .northUp:     return "location.fill"
        }
    }

    var label: String {
        switch self {
        case .followRoute: return "ROUTE"
        case .headingUp:   return "AHEAD"
        case .northUp:     return "NORTH"
        }
    }

    /// True when the map is pinned to the rider at a fixed zoom (vs. framing the
    /// whole route). headingUp + northUp are pinned-follow; followRoute frames.
    var isPinnedFollow: Bool { self != .followRoute }
}

// MARK: - LiveRouteMap
//
// A real dark-styled MapKit map with the live route drawn on top. The rider sees
// real streets/context while recording; the accent route line stays the hero.
//
// Behaviors by FollowMode:
//   • followRoute (default): frames a bounded trailing window of the DRAWN route
//     with asymmetric margins (route sits in the upper region, clear of the HUD),
//     north-up. As you ride, the frame slides to keep your recent route + current
//     position visible — the keepsake stays on screen.
//   • headingUp / northUp (pinned follow): center on the CURRENT position at a
//     fixed zoom with the rider pinned near the lower third so the road ahead
//     opens up above (and clears the HUD). headingUp rotates the map to the
//     travel bearing; northUp keeps north up.
//
// NOTE (verification): MapKit tiles require network; they load on device and on
// GitHub CI runners. If tiles are ever unavailable, the polyline + markers still
// render over the base — the route (the hero) is never lost.

struct LiveRouteMap: View {
    let samples: [RideSample]
    var routeColor: Color = Theme.Palette.accent
    var mode: FollowMode = .followRoute

    // Pinned-follow tuning (headingUp / northUp) ----------------------------
    /// Camera distance (meters) in pinned-follow modes — a comfortable "riding"
    /// zoom that shows the next corners plus surrounding terrain.
    var followDistance: Double = 2200
    /// Where the rider sits vertically in pinned-follow: 0 = top, 1 = bottom.
    /// ~0.62 keeps you in the lower third so the road ahead fills the screen and
    /// you stay clear of the bottom stats HUD (which starts ~65% down).
    var pitchAnchor: Double = 0.62
    /// MapKit's visible ground extent ≈ this × camera distance (pitch 0, default
    /// FOV). Converts the desired screen anchor into a look-ahead offset.
    private let verticalExtentFactor: Double = 0.536

    // Route-framed tuning (followRoute) -------------------------------------
    /// Trailing length of route to keep framed (meters). Frames the whole route
    /// until it exceeds this, then the most-recent chunk — so a 300 km ride still
    /// shows a meaningful, readable route rather than a shrinking dot.
    var routeWindowMeters: Double = 20_000
    /// Extra framing below the route (× its lat span) to push it up, reserving
    /// room for the HUD.
    var bottomHeadroom: Double = 1.15
    /// Small margin above the route so the north end never touches the top edge.
    var topHeadroom: Double = 0.18

    @State private var camera: MapCameraPosition = .automatic

    private var coords: [CLLocationCoordinate2D] {
        samples.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $camera, interactionModes: []) {
            if coords.count > 1 {
                // Glow-ish underlay (wider, translucent) + crisp line on top.
                MapPolyline(coordinates: coords)
                    .stroke(routeColor.opacity(0.35), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: coords)
                    .stroke(routeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                if let start = coords.first {
                    Annotation("", coordinate: start) {
                        Circle().fill(Theme.Palette.success)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                    }
                }
                if let now = coords.last {
                    Annotation("", coordinate: now) {
                        // In heading-up the map rotates (up == ahead) so a plain
                        // dot suffices; otherwise show a heading chevron.
                        RiderMarker(color: routeColor,
                                    heading: mode == .headingUp ? nil : currentBearing)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .preferredColorScheme(.dark)
        .onAppear { updateCamera() }
        .onChange(of: samples.count) { _, _ in updateCamera() }
        .onChange(of: mode) { _, _ in updateCamera() }
    }

    // MARK: Camera

    private func updateCamera() {
        guard samples.count > 1 else { return }
        if mode.isPinnedFollow { follow() } else { fitFollowRoute() }
    }

    /// Bearing (degrees) of the rider's current travel direction, from the last
    /// couple of fixes. Rotates the map (headingUp) and orients the marker.
    private var currentBearing: Double {
        guard samples.count >= 2 else { return 0 }
        let tail = Array(samples.suffix(4))
        var sumSin = 0.0, sumCos = 0.0
        for i in 1..<tail.count {
            let b = RideMetrics.bearing(tail[i - 1], tail[i]) * .pi / 180
            sumSin += sin(b); sumCos += cos(b)
        }
        let avg = atan2(sumSin, sumCos) * 180 / .pi
        return (avg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// PINNED FOLLOW: center on the current position, pinned low on screen, fixed
    /// zoom. headingUp rotates the map to the travel bearing; northUp keeps north.
    private func follow() {
        guard let last = samples.last else { return }
        let here = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)

        let heading = mode == .headingUp ? currentBearing : 0
        // Push the camera's look-at point AHEAD of the rider so the rider sits at
        // `pitchAnchor` (lower third). Visible vertical extent ≈ factor × distance;
        // shift the center by (anchor-0.5) of the half-extent along the heading.
        let halfExtent = followDistance * verticalExtentFactor / 2
        let aheadMeters = (pitchAnchor - 0.5) * 2 * halfExtent
        let center = Self.coordinate(from: here, distanceMeters: aheadMeters, bearingDegrees: heading)

        let cam = MapCamera(
            centerCoordinate: center,
            distance: followDistance,
            heading: heading,
            pitch: 0
        )
        withAnimation(Theme.Motion.smooth) { camera = .camera(cam) }
    }

    /// ROUTE-FRAMED FOLLOW: frame a bounded trailing window of the drawn route so
    /// the rider's keepsake stays visible (north-up), following as it grows.
    private func fitFollowRoute() {
        guard samples.count > 1 else { return }
        // Walk back from the current position accumulating distance until we've
        // covered routeWindowMeters (or the whole route).
        var window: [RideSample] = [samples[samples.count - 1]]
        var dist = 0.0
        var i = samples.count - 1
        while i > 0 && dist < routeWindowMeters {
            dist += RideMetrics.haversine(samples[i - 1], samples[i])
            window.append(samples[i - 1])
            i -= 1
        }
        fitRegion(window)
    }

    /// Frame `pts` into the UPPER region with asymmetric top/bottom margins so the
    /// route sits high (both ends visible) and clears the bottom HUD. North-up.
    private func fitRegion(_ pts: [RideSample]) {
        let lats = pts.map(\.latitude), lons = pts.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let rawLatSpan = max(maxLat - minLat, 0.002)
        let rawLonSpan = max(maxLon - minLon, 0.002)

        let latSpan = rawLatSpan * (1 + topHeadroom + bottomHeadroom)
        let lonSpan = max(rawLonSpan * 1.35, latSpan * 0.62)

        let centerLat = maxLat + rawLatSpan * topHeadroom - latSpan / 2
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: (minLon + maxLon) / 2
        )
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        withAnimation(Theme.Motion.smooth) { camera = .region(region) }
    }

    /// Project a coordinate `distanceMeters` along `bearingDegrees` from `origin`.
    static func coordinate(from origin: CLLocationCoordinate2D,
                           distanceMeters: Double,
                           bearingDegrees: Double) -> CLLocationCoordinate2D {
        let R = 6_371_000.0
        let d = distanceMeters / R
        let brng = bearingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng))
        let lon2 = lon1 + atan2(sin(brng) * sin(d) * cos(lat1),
                                cos(d) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi,
                                      longitude: lon2 * 180 / .pi)
    }
}

// MARK: - RiderMarker
//
// The "you are here" marker. A glowing dot; when a heading is provided (route /
// north-up modes) it wears a directional chevron so travel direction stays
// readable without the map rotating. In heading-up mode the map itself rotates,
// so the marker stays a plain dot (up == ahead already).

private struct RiderMarker: View {
    let color: Color
    /// Travel bearing in degrees, or nil to show a plain dot (heading-up).
    let heading: Double?

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: 34, height: 34)
            if let heading {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(heading))
                    .shadow(color: color, radius: 6)
            } else {
                Circle().fill(color).frame(width: 16, height: 16)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: color, radius: 8)
            }
        }
    }
}
