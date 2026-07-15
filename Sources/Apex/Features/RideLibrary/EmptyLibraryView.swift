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
                Spacer()

                // Hero motif: the racing-line "apex" curve, glowing.
                ApexCurveMark()
                    .frame(width: 132, height: 132)
                    .padding(.bottom, Theme.Space.s8)

                Text("Your garage is empty")
                    .font(Theme.Font.titleL)
                    .tracking(Theme.Tracking.titleL)
                    .foregroundStyle(Theme.Palette.inkPrimary)
                    .multilineTextAlignment(.center)

                Text("Record your first ride and it'll live here —\nroute, distance, and every corner you carved.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, Theme.Space.s3)
                    .padding(.horizontal, Theme.Space.s6)

                Spacer()

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
// The brand motif: a stylized racing line sweeping through a corner apex, with
// an accent glow. Custom-drawn (DESIGN_SYSTEM §6 — not a stock SF Symbol).

public struct ApexCurveMark: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Soft accent halo.
                Circle()
                    .fill(Theme.Palette.accentGlow)
                    .blur(radius: 26)
                    .frame(width: w * 0.7, height: h * 0.7)

                // Track edges (subtle).
                ApexLine(inset: 0.12)
                    .stroke(Color.white.opacity(0.08),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                ApexLine(inset: 0.88)
                    .stroke(Color.white.opacity(0.08),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // The racing line itself — accent, glowing.
                ApexLine(inset: 0.5)
                    .stroke(Theme.Palette.accent.opacity(0.4),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .blur(radius: 7)
                ApexLine(inset: 0.5)
                    .stroke(Theme.accentGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))

                // Apex point marker.
                Circle()
                    .fill(Theme.Palette.inkPrimary)
                    .frame(width: 9, height: 9)
                    .position(x: w * 0.5, y: h * 0.62)
                    .shadow(color: Theme.Palette.accent, radius: 6)
            }
        }
    }
}

// A corner: enters top-left, apexes low-center, exits top-right. `inset` shifts
// the line across the track width (0 = inside edge, 1 = outside edge).
struct ApexLine: Shape {
    var inset: CGFloat
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let apexY = h * (0.50 + 0.20 * inset)   // outer lines apex later/higher
        var p = Path()
        p.move(to: CGPoint(x: w * 0.08, y: h * 0.10))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.10),
            control: CGPoint(x: w * 0.5, y: apexY + h * 0.55)
        )
        return p
    }
}
