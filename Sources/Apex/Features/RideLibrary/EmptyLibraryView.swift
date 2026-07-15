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

            // One centered content block → tight, intentional vertical rhythm
            // (no mid-screen void). Buttons follow the copy directly.
            VStack(spacing: 0) {
                Spacer()

                ApexCurveMark()
                    .frame(width: 108, height: 92)

                Text("Your garage is empty")
                    .font(Theme.Font.titleL)
                    .tracking(Theme.Tracking.titleL)
                    .foregroundStyle(Theme.Palette.inkPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Space.s8)

                Text("Record your first ride and it'll live here — route, distance, and every corner you carved.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, Theme.Space.s3)
                    .padding(.horizontal, Theme.Space.s8)

                // Actions follow the copy directly (modest gap, not a void).
                VStack(spacing: Theme.Space.s3) {
                    primaryButton
                    secondaryButton
                    Text("Demo mode fills your garage with sample rides so you can look around. Nothing is saved.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, Theme.Space.s1)
                        .padding(.horizontal, Theme.Space.s4)
                }
                .padding(.top, Theme.Space.s10)

                Spacer()
            }
            .padding(.horizontal, Theme.Space.screenInset)
        }
    }

    // MARK: Buttons

    private var primaryButton: some View {
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
    }

    private var secondaryButton: some View {
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
                    .fill(Theme.Palette.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: Theme.Radius.hairline)
            )
        }
        .buttonStyle(.plain)
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
            let apexX = w * 0.5
            let apexY = h * 0.72
            ZStack {
                // Single, tight glow underlay along the line itself (no separate
                // halo circle — that created a lopsided bloom illusion). One
                // blurred stroke of the SAME curve keeps the glow symmetric.
                ApexCurve(depth: 0.72)
                    .stroke(Theme.Palette.accent.opacity(0.45),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .blur(radius: 5)

                // The racing line — crisp accent gradient.
                ApexCurve(depth: 0.72)
                    .stroke(Theme.accentGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))

                // Apex point, anchored exactly to the curve's lowest point.
                Circle()
                    .fill(Theme.Palette.inkPrimary)
                    .frame(width: 10, height: 10)
                    .position(x: apexX, y: apexY)
                    .shadow(color: Theme.Palette.accent, radius: 4)
            }
        }
    }
}

// A symmetric corner: enters top-left, dips to an apex at bottom-center, exits
// top-right. `depth` is the fraction of height the apex reaches (0..1). Built as
// two mirror-image quadratic curves meeting at the apex, exactly symmetric about
// the vertical center line. The apex control points share the apex Y so the two
// halves meet smoothly (continuous tangent) at the lowest point.
struct ApexCurve: Shape {
    var depth: CGFloat
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let topY = h * 0.08
        let apex = CGPoint(x: w * 0.5, y: h * depth)
        let left = CGPoint(x: w * 0.14, y: topY)
        let right = CGPoint(x: w * 0.86, y: topY)
        var p = Path()
        p.move(to: left)
        p.addQuadCurve(to: apex, control: CGPoint(x: w * 0.28, y: apex.y))
        p.addQuadCurve(to: right, control: CGPoint(x: w * 0.72, y: apex.y))
        return p
    }
}
