import SwiftUI

// MARK: - RideLibraryView
//
// The hero screen: a rider's garage of rides (Principle P2).
// Layout:
//   • Large title "Rides" + a hero summary strip (lifetime distance = the one
//     big accent number; ride count + lifetime time as supporting stats).
//   • A scrolling collection of RideCardView keepsakes (staggered entrance).
//   • A bottom-anchored primary "Record" action (thumb reach, P3), floating on
//     a gradient scrim so it never fights the content.
//
// Everything renders from SampleData — no live dependencies (ARCHITECTURE A3).

public struct RideLibraryView: View {
    public let rides: [Ride]
    public init(rides: [Ride] = SampleData.rides) { self.rides = rides }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Theme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.s6) {
                    header
                    ForEach(Array(rides.enumerated()), id: \.element.id) { _, ride in
                        RideCardView(ride: ride)
                    }
                    // Bottom breathing room so the last card clears the button.
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, Theme.Space.screenInset)
                .padding(.top, Theme.Space.s6)
            }

            recordButton
        }
    }

    // MARK: Hero header

    private var header: some View {
        let totalDist = rides.reduce(0.0) { $0 + RideMetrics.distanceMeters($1.samples) }
        let totalTime = rides.reduce(0.0) { $0 + RideMetrics.elapsedDuration($1) }

        return VStack(alignment: .leading, spacing: Theme.Space.s5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rides")
                    .font(Theme.Font.titleL)
                    .tracking(Theme.Tracking.titleL)
                    .foregroundStyle(Theme.Palette.inkPrimary)
                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.Palette.inkTertiary)
            }

            // Hero summary: the ONE big accent number = lifetime distance.
            HStack(alignment: .bottom, spacing: Theme.Space.s6) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(RideFormat.distance(totalDist))
                            .font(Theme.Font.displayXL)
                            .tracking(Theme.Tracking.displayXL)
                            .foregroundStyle(Theme.Palette.accent)
                            .monospacedDigit()
                        Text(RideFormat.distanceUnit)
                            .font(Theme.Font.title)
                            .foregroundStyle(Theme.Palette.accent.opacity(0.8))
                    }
                    Text("LIFETIME DISTANCE")
                        .font(Theme.Font.label)
                        .tracking(Theme.Tracking.label)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: Theme.Space.s3) {
                    StatBlock(value: "\(rides.count)", label: "Rides", alignment: .trailing)
                    StatBlock(value: RideFormat.duration(totalTime), label: "Time",
                              alignment: .trailing)
                }
            }
        }
    }

    // MARK: Primary action

    private var recordButton: some View {
        VStack(spacing: 0) {
            // Scrim so the button floats readably over scrolling cards.
            LinearGradient(
                colors: [Theme.Palette.canvasBottom.opacity(0), Theme.Palette.canvasBottom],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 80)
            .allowsHitTesting(false)

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
            .padding(.horizontal, Theme.Space.screenInset)
            .padding(.bottom, Theme.Space.s6)
            .background(Theme.Palette.canvasBottom)
        }
    }
}
