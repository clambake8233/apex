import SwiftUI

// MARK: - RideDetailView
//
// One ride, in full — the keepsake opened up (P2). Structure:
//   [ full-bleed dark route map (the hero, P1) with title + hero distance ]
//   [ elevation profile — the shape of the climb                          ]
//   [ stats grid — the trophies, INCLUDING top speed (its proper home)    ]
//   [ notes / ride story                                                  ]
//
// This is where Top Speed lives: celebrated in detail, not dangled on the list
// (the garage rewards the ROAD via Corners, not raw speed — see RideCardView).
//
// Renders entirely from a Ride value (SampleData in CI) — zero live deps (A3).

public struct RideDetailView: View {
    public let ride: Ride
    public var onClose: () -> Void = {}

    public init(ride: Ride, onClose: @escaping () -> Void = {}) {
        self.ride = ride
        self.onClose = onClose
    }

    private var color: Color { Theme.routeColor(for: ride.id) }

    public var body: some View {
        let dist = RideMetrics.distanceMeters(ride.samples)
        let moving = RideMetrics.movingDuration(ride.samples)
        let elapsed = RideMetrics.elapsedDuration(ride)
        let top = RideMetrics.topSpeedMetersPerSec(ride.samples)
        let avg = RideMetrics.avgSpeedMetersPerSec(ride.samples)
        let corners = RideMetrics.cornerCount(ride.samples)
        let climb = RideMetrics.elevationGainMeters(ride.samples)
        let maxAlt = RideMetrics.maxAltitudeMeters(ride.samples)

        ZStack(alignment: .top) {
            Theme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    mapHero(distance: dist)
                    VStack(alignment: .leading, spacing: Theme.Space.s6) {
                        elevationSection(climb: climb, maxAlt: maxAlt)
                        statsGrid(top: top, avg: avg, moving: moving,
                                  elapsed: elapsed, corners: corners, climb: climb)
                        if let notes = ride.notes, !notes.isEmpty {
                            notesSection(notes)
                        }
                        Color.clear.frame(height: Theme.Space.s8)
                    }
                    .padding(.horizontal, Theme.Space.screenInset)
                    .padding(.top, Theme.Space.s6)
                }
            }
            .ignoresSafeArea(edges: .top)

            topBar
        }
    }

    // MARK: Map hero

    private func mapHero(distance: Double) -> some View {
        ZStack(alignment: .bottomLeading) {
            RouteMapView(samples: ride.samples, routeColor: color)
                .frame(height: 420)

            // Bottom scrim so the title/hero-distance read over the map.
            LinearGradient(
                colors: [.clear, Theme.Palette.canvasTop.opacity(0.65), Theme.Palette.canvasTop],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 190)
            .allowsHitTesting(false)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Title, date, and the hero distance stat.
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                HStack(spacing: Theme.Space.s3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 4, height: 30)
                        .themeShadow(Theme.Shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 0))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ride.title)
                            .font(Theme.Font.titleL).tracking(Theme.Tracking.titleL)
                            .foregroundStyle(Theme.Palette.inkPrimary)
                            .lineLimit(1)
                        Text("\(RideFormat.dayLabel(ride.startedAt, now: SampleData.referenceNow())) · \(RideFormat.timeOfDay(ride.startedAt))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(RideFormat.distance(distance))
                        .font(Theme.Font.displayXL).tracking(Theme.Tracking.displayXL)
                        .foregroundStyle(Theme.Palette.accent)
                        .monospacedDigit()
                    Text(RideFormat.distanceUnit)
                        .font(Theme.Font.title)
                        .foregroundStyle(Theme.Palette.accent.opacity(0.8))
                }
            }
            .padding(.horizontal, Theme.Space.screenInset)
            .padding(.bottom, Theme.Space.s5)
        }
        .frame(height: 420)
        .clipped()
    }

    // MARK: Elevation

    private func elevationSection(climb: Double, maxAlt: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            HStack {
                sectionLabel("ELEVATION")
                Spacer()
                HStack(spacing: Theme.Space.s2) {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Palette.elevation)
                    Text("\(RideFormat.elevation(climb)) \(RideFormat.elevationUnit) climb")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            ElevationProfile(samples: ride.samples, color: color)
                .frame(height: 84)
        }
        .padding(Theme.Space.s4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.surfaceStroke, lineWidth: Theme.Radius.hairline)
        )
        .themeShadow(Theme.Elevation.e1)
    }

    // MARK: Stats grid

    private func statsGrid(top: Double, avg: Double, moving: TimeInterval,
                           elapsed: TimeInterval, corners: Int, climb: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s4) {
            sectionLabel("RIDE STATS")
            let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: Theme.Space.s5) {
                gridStat(RideFormat.speed(top), "km/h", "Top Speed", tint: Theme.Palette.speed)
                gridStat(RideFormat.speed(avg), "km/h", "Avg Speed")
                gridStat("\(corners)", nil, "Corners", tint: color)
                gridStat(RideFormat.duration(moving), nil, "Moving")
                gridStat(RideFormat.duration(elapsed), nil, "Elapsed")
                gridStat(RideFormat.elevation(climb), "m", "Climb", tint: Theme.Palette.elevation)
            }
        }
        .padding(Theme.Space.s5)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.surfaceStroke, lineWidth: Theme.Radius.hairline)
        )
        .themeShadow(Theme.Elevation.e1)
    }

    private func gridStat(_ value: String, _ unit: String?, _ label: String,
                          tint: Color = Theme.Palette.inkPrimary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.Font.stat)
                    .foregroundStyle(tint)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                }
            }
            Text(label.uppercased())
                .font(Theme.Font.label).tracking(Theme.Tracking.label)
                .foregroundStyle(Theme.Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            sectionLabel("NOTES")
            Text(notes)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.s5)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.surfaceStroke, lineWidth: Theme.Radius.hairline)
        )
    }

    // MARK: Chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.label).tracking(Theme.Tracking.label)
            .foregroundStyle(Theme.Palette.inkTertiary)
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.inkPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.Palette.surface.opacity(0.7)))
                    .overlay(Circle().strokeBorder(Theme.Palette.surfaceStroke, lineWidth: Theme.Radius.hairline))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, Theme.Space.screenInset)
        .padding(.top, Theme.Space.s2)
    }
}
