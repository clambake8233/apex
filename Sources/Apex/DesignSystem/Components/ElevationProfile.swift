import SwiftUI

// MARK: - ElevationProfile
//
// A compact area-sparkline of the ride's altitude over distance — the "shape" of
// the ride's climb. Kinetic and information-dense (DESIGN_PRINCIPLES §0.3, §3),
// drawn in the ride's identity color with a soft gradient fill. Renders headless
// (pure Shape math, no live deps) so it verifies in CI like everything else.
//
// This is the elevation equivalent of RoutePath: it turns a column of altitude
// numbers into a glanceable object, so the detail screen reads as a story (you
// climbed a pass) rather than a table.

struct ElevationProfile: View {
    let samples: [RideSample]
    var color: Color = Theme.Palette.accent

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            if pts.count > 1 {
                ZStack {
                    // Soft gradient fill under the line (area chart).
                    ElevationArea(points: pts)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.35), color.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    // Glow underlay + crisp ridge line.
                    ElevationLine(points: pts)
                        .stroke(color.opacity(0.30),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .blur(radius: 3)
                    ElevationLine(points: pts)
                        .stroke(color,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    /// Map samples → screen points, altitude on Y (inverted), index on X.
    private func points(in size: CGSize) -> [CGPoint] {
        guard samples.count > 1 else { return [] }
        let alts = samples.map(\.altitude)
        guard let lo = alts.min(), let hi = alts.max() else { return [] }
        let span = max(hi - lo, 1)
        let pad: CGFloat = 6
        let h = size.height - pad * 2
        let n = samples.count - 1
        return samples.enumerated().map { i, s in
            let x = size.width * CGFloat(i) / CGFloat(n)
            let norm = (s.altitude - lo) / span          // 0…1, low→high
            let y = pad + h * (1 - CGFloat(norm))         // invert: high = up
            return CGPoint(x: x, y: y)
        }
    }
}

private struct ElevationLine: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        return p
    }
}

private struct ElevationArea: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first, let last = points.last else { return p }
        p.move(to: CGPoint(x: first.x, y: rect.maxY))
        p.addLine(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        p.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
