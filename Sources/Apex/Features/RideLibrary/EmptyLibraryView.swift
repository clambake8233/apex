import SwiftUI

// MARK: - EmptyLibraryView
//
// The first-run, no-rides-yet moment. Per DESIGN_PRINCIPLES U7 this is a
// DESIGNED INVITATION, not an apology. It should make a rider want to go ride —
// and it offers Demo Mode so the app can be explored with zero data.
//
// Composition:
//   • A large "apex curve" motif drawn in the accent, glowing on the canvas.
//   • A confident headline + one line of supporting copy.
//   • Primary action: Record a Ride (the real first step).
//   • Secondary action: Try Demo Mode (explore with sample rides).

public struct EmptyLibraryView: View {
    public var onRecord: () -> Void = {}
    public var onTryDemo: () -> Void = {}

    public init(onRecord: @escaping () -> Void = {}, onTryDemo: @escaping () -> Void = {}) {
        self.onRecord = onRecord
        self.onTryDemo = onTryDemo
    }

    public var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Theme.Space.s10)

                // Hero motif: the racing-line "apex" curve, glowing.
                ApexCurveMark()
                    .frame(width: 116, height: 116)
                    .padding(.bottom, Theme.Space.s6)

                Text("Your garage is empty")
                    .font(Theme.Font.titleL)
                    .tracking(Theme.Tracking.titleL)
                    .foregroundStyle(Theme.Palette.inkPrimary)
                    .multilineTextAlignment(.center)

                Text("Record your first ride and it'll live here — route, distance, and every corner you carved.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, Theme.Space.s3)
                    .padding(.horizontal, Theme.Space.s8)

                Spacer(minLength: Theme.Space.s10)

                VStack(spacing: Theme.Space.s3) {
                    // Primary — the real first step.
                    Button(action: onRecord) {
                        HStack(spacing: Theme.Space.s2) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 20, weight: .bold))
                            Text("Record a Ride")
                                .font(Theme.Font.bodyEmphasis)
                        }
                        .foregroundStyle(Theme.Palette.inkInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Space.primaryButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Theme.accentGradient)
                        )
                        .themeShadow(Theme.Elevation.accent)
                    }
                    .buttonStyle(.plain)

                    // Secondary — explore with sample data.
                    Button(action: onTryDemo) {
                        HStack(spacing: Theme.Space.s2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Try Demo Mode")
                                .font(Theme.Font.bodyEmphasis)
                        }
                        .foregroundStyle(Theme.Palette.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Space.primaryButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Theme.Palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .strokeBorder(Theme.Palette.surfaceStroke, lineWidth: Theme.Radius.hairline)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Demo mode fills your garage with sample rides so you\ncan look around. Nothing is saved.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, Theme.Space.s1)
                }
                .padding(.horizontal, Theme.Space.screenInset)
                .padding(.bottom, Theme.Space.s8)
            }
        }
    }
}

// MARK: - ApexCurveMark
//
// The brand motif: a clean, symmetric racing line sweeping down through a corner
// apex and back out, with a controlled accent glow and the apex point anchored
// exactly to the curve's lowest point. Custom-drawn (DESIGN_SYSTEM §6 — not a
// stock SF Symbol). Symmetry and a tight glow are what make it read as an
// engineered mark rather than a freehand swoosh.

public struct ApexCurveMark: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // The apex sits at the curve's lowest point (center-x, apexY).
            let apexX = w * 0.5
            let apexY = h * 0.72
            ZStack {
                // Soft, contained accent halo centered on the apex.
                Circle()
                    .fill(Theme.Palette.accentGlow)
                    .frame(width: w * 0.5, height: w * 0.5)
                    .blur(radius: 18)
                    .position(x: apexX, y: apexY)

                // Faint outer "track edge" echo (symmetric).
                ApexCurve(depth: 0.58)
                    .stroke(Color.white.opacity(0.07),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // The racing line — accent, with a tight glow underlay.
                ApexCurve(depth: 0.72)
                    .stroke(Theme.Palette.accent.opacity(0.35),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .blur(radius: 4)
                ApexCurve(depth: 0.72)
                    .stroke(Theme.accentGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))

                // Apex point marker, anchored to the curve's lowest point.
                Circle()
                    .fill(Theme.Palette.inkPrimary)
                    .frame(width: 10, height: 10)
                    .position(x: apexX, y: apexY)
                    .shadow(color: Theme.Palette.accent, radius: 5)
            }
        }
    }
}

// A symmetric corner: enters top-left, dips to an apex at bottom-center, exits
// top-right. `depth` is the fraction of height the apex reaches (0..1). Built as
// two mirror-image quadratic curves meeting at the apex, so it's exactly
// symmetric about the vertical center line.
struct ApexCurve: Shape {
    var depth: CGFloat
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let topY = h * 0.14
        let apex = CGPoint(x: w * 0.5, y: h * depth)
        let left = CGPoint(x: w * 0.12, y: topY)
        let right = CGPoint(x: w * 0.88, y: topY)
        var p = Path()
        p.move(to: left)
        // Left half: control pulls straight down toward the apex depth.
        p.addQuadCurve(to: apex, control: CGPoint(x: w * 0.26, y: apex.y))
        // Right half: mirror image.
        p.addQuadCurve(to: right, control: CGPoint(x: w * 0.74, y: apex.y))
        return p
    }
}
