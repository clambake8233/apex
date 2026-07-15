import SwiftUI

// MARK: - RideLibraryView
//
// The hero screen: a rider's garage of rides (Principle P2). Now store-driven so
// it reacts to mode (empty / demo / live):
//   • empty → the designed EmptyLibraryView invitation (with Try Demo Mode)
//   • demo/live → the hero summary + ride keepsake cards
//
// In demo mode a "DEMO" pill sits in the header with an Exit affordance, so the
// state is always honest and reversible.
//
// Everything renders from the store; sample/demo data has zero live deps
// (ARCHITECTURE A3).

public struct RideLibraryView: View {
    @State private var store: RideStore

    public init(store: RideStore = RideStore(mode: .demo)) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Theme.canvas.ignoresSafeArea()

            if store.hasRides {
                content
                recordButton
            } else {
                EmptyLibraryView(
                    onRecord: { /* recording screen — next feature */ },
                    onTryDemo: { withAnimation(Theme.Motion.smooth) { store.enterDemo() } }
                )
            }
        }
    }

    // MARK: Ride list

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s6) {
                header
                ForEach(store.rides, id: \.id) { ride in
                    RideCardView(ride: ride)
                }
                // Clearance so the last card fully scrolls above the floating
                // Record button + its scrim (button 58 + paddings + scrim).
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, Theme.Space.screenInset)
            .padding(.top, Theme.Space.s6)
        }
    }

    // MARK: Hero header

    private var header: some View {
        let rides = store.rides
        let totalDist = rides.reduce(0.0) { $0 + RideMetrics.distanceMeters($1.samples) }
        let totalTime = rides.reduce(0.0) { $0 + RideMetrics.elapsedDuration($1) }

        return VStack(alignment: .leading, spacing: Theme.Space.s5) {
            HStack(alignment: .center) {
                Text("Rides")
                    .font(Theme.Font.titleL)
                    .tracking(Theme.Tracking.titleL)
                    .foregroundStyle(Theme.Palette.inkPrimary)

                if store.isDemo {
                    Button {
                        withAnimation(Theme.Motion.smooth) { store.exitDemo() }
                    } label: {
                        HStack(spacing: Theme.Space.s1) {
                            Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
                            Text("DEMO")
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .font(Theme.Font.label)
                        .tracking(Theme.Tracking.label)
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, Theme.Space.s3)
                        .padding(.vertical, Theme.Space.s1 + 2)
                        .background(Capsule().fill(Theme.Palette.accent.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.Palette.inkTertiary)
            }

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
            // Tall, soft scrim so cards fade under the button intentionally
            // (reads as a deliberate fade, not a hard clip).
            LinearGradient(
                colors: [
                    Theme.Palette.canvasBottom.opacity(0),
                    Theme.Palette.canvasBottom.opacity(0.7),
                    Theme.Palette.canvasBottom,
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
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
