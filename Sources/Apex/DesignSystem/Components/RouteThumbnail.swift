import SwiftUI

// MARK: - RoutePath
//
// A Shape that draws a ride's GPS track, normalized to fit its rect with
// padding. Renders headless (no MapKit tiles) so it works in the fast snapshot
// harness and as a card "keepsake" thumbnail. The full interactive MapKit map
// is reserved for the detail screen (Tier 2 verification).

public struct RoutePath: Shape {
    public let coordinates: [(lat: Double, lon: Double)]
    public var padding: CGFloat = 10

    public init(samples: [RideSample], padding: CGFloat = 10) {
        self.coordinates = samples.map { ($0.latitude, $0.longitude) }
        self.padding = padding
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard coordinates.count > 1 else { return path }

        let lats = coordinates.map(\.lat)
        let lons = coordinates.map(\.lon)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return path }

        let spanLat = max(maxLat - minLat, 1e-6)
        let spanLon = max(maxLon - minLon, 1e-6)

        // Fit while preserving aspect ratio (don't distort the route shape).
        let availW = rect.width - padding * 2
        let availH = rect.height - padding * 2
        // Longitude degrees compress with latitude; correct so the shape is true.
        let midLat = (minLat + maxLat) / 2
        let lonScale = cos(midLat * .pi / 180)
        let geoW = spanLon * lonScale
        let geoH = spanLat
        let scale = min(availW / geoW, availH / geoH)

        let drawW = geoW * scale
        let drawH = geoH * scale
        let offsetX = padding + (availW - drawW) / 2
        let offsetY = padding + (availH - drawH) / 2

        func point(_ lat: Double, _ lon: Double) -> CGPoint {
            let x = offsetX + ((lon - minLon) * lonScale) * scale
            // Flip Y: higher latitude = up on screen.
            let y = offsetY + (maxLat - lat) * scale
            return CGPoint(x: x, y: y)
        }

        path.move(to: point(coordinates[0].lat, coordinates[0].lon))
        for c in coordinates.dropFirst() {
            path.addLine(to: point(c.lat, c.lon))
        }
        return path
    }

    /// Normalized endpoint positions (for start/end dots), same transform.
    public func endpoints(in rect: CGRect) -> (start: CGPoint, end: CGPoint)? {
        guard let first = coordinates.first, let last = coordinates.last else { return nil }
        let p = path(in: rect)   // ensures same transform is valid
        _ = p
        // Recompute via a 1-point path trick: reuse path(in:) transform by
        // building a tiny helper. Simpler: replicate the transform inline.
        let lats = coordinates.map(\.lat), lons = coordinates.map(\.lon)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let spanLat = max(maxLat - minLat, 1e-6), spanLon = max(maxLon - minLon, 1e-6)
        let availW = rect.width - padding * 2, availH = rect.height - padding * 2
        let midLat = (minLat + maxLat) / 2
        let lonScale = cos(midLat * .pi / 180)
        let geoW = spanLon * lonScale, geoH = spanLat
        let scale = min(availW / geoW, availH / geoH)
        let drawW = geoW * scale, drawH = geoH * scale
        let offsetX = padding + (availW - drawW) / 2
        let offsetY = padding + (availH - drawH) / 2
        func pt(_ lat: Double, _ lon: Double) -> CGPoint {
            CGPoint(x: offsetX + ((lon - minLon) * lonScale) * scale,
                    y: offsetY + (maxLat - lat) * scale)
        }
        return (pt(first.lat, first.lon), pt(last.lat, last.lon))
    }
}

// MARK: - RouteThumbnail
//
// The card's "picture of the ride": the route drawn in its identity color with
// a soft same-hue glow, over a dark styled panel. Framed like a photo (P2).

public struct RouteThumbnail: View {
    public let ride: Ride
    public var height: CGFloat = 150

    public init(ride: Ride, height: CGFloat = 150) {
        self.ride = ride
        self.height = height
    }

    public var body: some View {
        let color = Theme.routeColor(for: ride.id)
        GeometryReader { geo in
            ZStack {
                // Dark map-like panel with a subtle radial depth.
                RoundedRectangle(cornerRadius: Theme.Radius.cardSm, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Theme.Palette.surfaceRaised, Theme.Palette.surface],
                            center: .center, startRadius: 4, endRadius: geo.size.width * 0.9
                        )
                    )

                // Faint grid texture — reads as a map without real tiles.
                RouteGrid()
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)

                let shape = RoutePath(samples: ride.samples, padding: 18)

                // Outer glow (neon on dark, DESIGN_SYSTEM §7).
                shape
                    .stroke(color.opacity(0.35),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                    .blur(radius: 6)

                // The route line itself.
                shape
                    .stroke(color,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                // Start (green) & end (accent) dots.
                if let ends = shape.endpoints(in: CGRect(origin: .zero, size: geo.size)) {
                    Circle().fill(Theme.Palette.success)
                        .frame(width: 9, height: 9)
                        .position(ends.start)
                    Circle().fill(Theme.Palette.accent)
                        .frame(width: 9, height: 9)
                        .position(ends.end)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cardSm, style: .continuous))
    }
}

// A very light diagonal grid to suggest a map surface.
struct RouteGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 26
        var x: CGFloat = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            x += step
        }
        return p
    }
}
