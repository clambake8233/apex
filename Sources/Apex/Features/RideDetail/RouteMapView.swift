import SwiftUI
import MapKit

// MARK: - RouteMapView
//
// A static, dark-styled MapKit map showing a COMPLETED ride's full route as the
// hero of the detail screen (ARCHITECTURE §3: "the full interactive MapKit map is
// reserved for the detail screen"). Non-interactive by default — it's a
// keepsake, not a navigation surface. The route is drawn as a layered accent
// polyline with start/finish markers, framed to fit with comfortable padding.
//
// Falls back gracefully: if tiles are slow/unavailable, the polyline + markers
// still render over the base — the route (the hero) is never lost.

struct RouteMapView: View {
    let samples: [RideSample]
    var routeColor: Color = Theme.Palette.accent
    /// Fraction padding around the route's bounding span.
    var pad: Double = 0.35

    @State private var camera: MapCameraPosition = .automatic

    private var coords: [CLLocationCoordinate2D] {
        samples.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $camera, interactionModes: []) {
            if coords.count > 1 {
                MapPolyline(coordinates: coords)
                    .stroke(routeColor.opacity(0.32),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: coords)
                    .stroke(routeColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                if let start = coords.first {
                    Annotation("", coordinate: start) {
                        Circle().fill(Theme.Palette.success)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                            .shadow(color: Theme.Palette.success.opacity(0.6), radius: 5)
                    }
                }
                if let finish = coords.last {
                    Annotation("", coordinate: finish) {
                        // Checkered-flag style finish: accent ring with a solid core.
                        ZStack {
                            Circle().fill(routeColor.opacity(0.22)).frame(width: 30, height: 30)
                            Circle().fill(routeColor).frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                        .shadow(color: routeColor, radius: 7)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .preferredColorScheme(.dark)
        .onAppear { fit() }
        .onChange(of: samples.count) { _, _ in fit() }
    }

    private func fit() {
        guard samples.count > 1 else { return }
        let lats = samples.map(\.latitude), lons = samples.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let latSpan = max((maxLat - minLat) * (1 + pad * 2), 0.003)
        let lonSpan = max((maxLon - minLon) * (1 + pad * 2), 0.003)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        withAnimation(Theme.Motion.smooth) { camera = .region(region) }
    }
}
