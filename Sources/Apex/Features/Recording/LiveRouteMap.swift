import SwiftUI
import MapKit

// MARK: - FollowMode
//
// How the live map tracks the rider (P3: predictable, glanceable while moving).
//   • headingUp — DEFAULT. The rider is pinned at a fixed spot near the bottom of
//     the screen and the map ROTATES so the road ahead is always "up" (nav-style).
//     Most intuitive in motion: what's ahead of you is ahead on screen.
//   • northUp  — the rider stays pinned, but north stays up; the world doesn't
//     spin. Calmer, no rotation, at the cost of mentally rotating the map.
//   • overview — the classic whole-route fit (auto-zooms out as the ride grows).
//     Not a "follow" mode; good for a glance at the entire ride so far.
public enum FollowMode: String, CaseIterable, Sendable {
    case headingUp
    case northUp
    case overview

    var next: FollowMode {
        switch self {
        case .headingUp: return .northUp
        case .northUp:   return .overview
        case .overview:  return .headingUp
        }
    }

    var iconName: String {
        switch self {
        case .headingUp: return "location.north.line.fill"
        case .northUp:   return "location.fill"
        case .overview:  return "map.fill"
        }
    }

    var label: String {
        switch self {
        case .headingUp: return "AHEAD"
        case .northUp:   return "NORTH"
        case .overview:  return "ROUTE"
        }
    }
}

// MARK: - LiveRouteMap
//
// A real dark-styled MapKit map with the live route drawn on top. The rider sees
// real streets/context while recording; the accent route line stays the hero.
//
// Two behaviors, chosen by FollowMode:
//   • FOLLOW (headingUp/northUp): the camera centers on the rider's CURRENT
//     position at a fixed zoom, with the position pinned near the lower third of
//     the screen so the road ahead opens up above (and it clears the stats HUD).
//     headingUp also rotates the map to the rider's travel bearing. As you ride,
//     the map slides (and rotates) under a fixed "you are here" marker — like a
//     navigation app. This is what answers "will it follow me?": YES, and you
//     stay put on screen while the world moves beneath you.
//   • OVERVIEW: frames the whole route with asymmetric margins (route sits in the
//     upper region, both endpoints visible, clear of the HUD). Zooms out as the
//     ride grows.
//
// NOTE (verification): MapKit tiles require network; they load on device and on
// GitHub CI runners. If tiles are ever unavailable, the polyline + markers still
// render over the base — the route (the hero) is never lost.

struct LiveRouteMap: View {
    let samples: [RideSample]
    var routeColor: Color = Theme.Palette.accent
    var mode: FollowMode = .headingUp

    // Follow tuning ---------------------------------------------------------
    /// Camera distance (meters) in follow modes — a comfortable "riding" zoom
    /// that shows the next few corners plus surrounding terrain without losing
    /// your dot. (Too tight = empty featureless frame; this shows road context.)
    var followDistance: Double = 2200
    /// Where the rider sits vertically in follow modes: 0 = top, 1 = bottom.
    /// ~0.62 keeps you in the lower third so the road ahead fills the screen and
    /// you stay clear of the bottom stats HUD (which starts ~65% down).
    var pitchAnchor: Double = 0.62
    /// MapKit's visible ground extent ≈ this × camera distance (pitch 0, default
    /// FOV). Used to convert the desired screen anchor into a look-ahead offset.
    private let verticalExtentFactor: Double = 0.536

    // Overview tuning -------------------------------------------------------
    /// Extra framing below the route (× its own lat span) to push it upward and
    /// reserve room for the HUD.
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
        switch mode {
        case .headingUp, .northUp: follow()
        case .overview:            fitOverview()
        }
    }

    /// Bearing (degrees) of the rider's current travel direction, from the last
    /// couple of fixes. Used to rotate the map (headingUp) and orient the marker.
    private var currentBearing: Double {
        guard samples.count >= 2 else { return 0 }
        // Average the last few hops so the heading isn't jittery.
        let tail = Array(samples.suffix(4))
        var sumSin = 0.0, sumCos = 0.0
        for i in 1..<tail.count {
            let b = RideMetrics.bearing(tail[i - 1], tail[i]) * .pi / 180
            sumSin += sin(b); sumCos += cos(b)
        }
        let avg = atan2(sumSin, sumCos) * 180 / .pi
        return (avg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// FOLLOW: center on the current position, pinned low on screen, fixed zoom.
    /// headingUp rotates the map to the travel bearing; northUp keeps north up.
    private func follow() {
        guard let last = samples.last else { return }
        let here = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)

        // To pin the rider near the LOWER third (pitchAnchor) while MapCamera
        // centers the viewport, offset the camera's center point AHEAD of the
        // rider along the travel bearing. With a flat map, shifting the center
        // north-of-rider (in screen space) moves the rider down on screen.
        let heading = mode == .headingUp ? currentBearing : 0
        // Push the camera's look-at point AHEAD of the rider so the rider sits at
        // `pitchAnchor` (lower third) on screen. The visible vertical extent is
        // ~verticalExtentFactor × distance; to move the rider DOWN by (anchor-0.5)
        // of the half-extent, shift the center that far ahead along the heading.
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

    /// OVERVIEW: frame the whole route into the UPPER region with asymmetric
    /// top/bottom margins so both endpoints stay visible and clear of the HUD.
    private func fitOverview() {
        let lats = samples.map(\.latitude), lons = samples.map(\.longitude)
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
// The "you are here" marker. A glowing dot; when a heading is provided (north-up
// mode) it wears a directional chevron so the rider can still read travel
// direction without the map rotating. In heading-up mode the map itself rotates,
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
