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
    /// How far below the route (as a multiple of the route's own latitude span)
    /// to extend the framed region, pushing the route into the UPPER part of the
    /// screen so both the start dot and the current-position marker stay visible
    /// and clear of the bottom stats HUD. Larger = route sits higher.
    var bottomHeadroom: Double = 1.15
    /// Small margin above the route so the start/finish never touches the top edge.
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

        // Base spans of the route itself.
        let rawLatSpan = max(maxLat - minLat, 0.002)
        let rawLonSpan = max(maxLon - minLon, 0.002)

        // Frame the route into the UPPER region using ASYMMETRIC vertical margins:
        // a small margin above (topHeadroom) keeps the north end off the top edge;
        // a large margin below (bottomHeadroom) reserves space for the stats HUD
        // and pushes the whole route up. This keeps BOTH the start dot and the
        // current-position marker on-screen and clear of the card (the previous
        // symmetric fit + south "bias" pushed the start point off the top).
        let latSpan = rawLatSpan * (1 + topHeadroom + bottomHeadroom)
        // Keep the map from over-zooming horizontally on a tall, narrow route.
        let lonSpan = max(rawLonSpan * 1.35, latSpan * 0.62)

        // Center latitude: place route so topHeadroom sits above maxLat.
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
}
