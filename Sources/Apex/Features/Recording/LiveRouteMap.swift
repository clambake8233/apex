import SwiftUI
import MapKit

// MARK: - LiveRouteMap
//
// A real dark-styled MapKit map with the live route drawn on top. Replaces the
// stylized canvas on the recording screen so the rider sees real streets/context
// while recording. The route line stays the hero (accent color, layered for a
// glow-like read) and the camera fits the route into the UPPER region so the
// current-position marker is never hidden behind the stats HUD.
//
// NOTE (verification): MapKit tiles require network; they load on device and on
// GitHub CI runners. If tiles are ever unavailable, the polyline + markers still
// render over the map's base — the route (the hero) is never lost.

struct LiveRouteMap: View {
    let samples: [RideSample]
    var routeColor: Color = Theme.Palette.accent
    /// Fraction of the latitude span to shift the camera south, so the route
    /// floats into the upper part of the screen (clear of the bottom HUD).
    var upperBias: Double = 0.18

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
                        ZStack {
                            Circle().fill(routeColor.opacity(0.25)).frame(width: 34, height: 34)
                            Circle().fill(routeColor).frame(width: 16, height: 16)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                        .shadow(color: routeColor, radius: 8)
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
        let latSpan = max((maxLat - minLat) * 1.5, 0.003)
        let lonSpan = max((maxLon - minLon) * 1.5, 0.003)
        // Shift center south so the route sits high on screen (clear of the HUD).
        let centerLat = (minLat + maxLat) / 2 - latSpan * upperBias
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: (minLon + maxLon) / 2)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        withAnimation(Theme.Motion.smooth) { camera = .region(region) }
    }
}
