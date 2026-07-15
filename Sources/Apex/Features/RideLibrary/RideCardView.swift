import SwiftUI

// MARK: - RideCardView
//
// One ride as a keepsake (Principle P2). Structure:
//   [ route thumbnail — the hero, framed like a photo         ]
//   [ identity spine | title            day · time-of-day     ]
//   [ distance   duration   corners       (trophy stats)      ]
//
// The per-ride identity color paints the route line AND a spine beside the
// title, so rides are recognizable by hue (our "Transit line color").
//
// NOTE: the third stat is CORNERS, not top speed — the list celebrates the
// road's character (how twisty the ride was), not raw speed. Top speed still
// lives on the ride detail screen; we just don't lead with it in the garage.

public struct RideCardView: View {
    public let ride: Ride
    public init(ride: Ride) { self.ride = ride }

    public var body: some View {
        let color = Theme.routeColor(for: ride.id)
        let dist = RideMetrics.distanceMeters(ride.samples)
        let dur = RideMetrics.elapsedDuration(ride)
        let corners = RideMetrics.cornerCount(ride.samples)

        ApexCard(padding: Theme.Space.s4) {
            VStack(alignment: .leading, spacing: Theme.Space.s4) {

                RouteThumbnail(ride: ride, height: 156)

                // Title row with identity spine.
                HStack(alignment: .center, spacing: Theme.Space.s3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 4, height: 34)
                        .themeShadow(Theme.Shadow(color: color.opacity(0.5),
                                                  radius: 6, x: 0, y: 0))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ride.title)
                            .font(Theme.Font.title)
                            .tracking(Theme.Tracking.title)
                            .foregroundStyle(Theme.Palette.inkPrimary)
                            .lineLimit(1)
                        Text("\(RideFormat.dayLabel(ride.startedAt, now: SampleData.referenceNow())) · \(RideFormat.timeOfDay(ride.startedAt))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.inkTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.inkTertiary)
                }

                // Trophy stats.
                HStack(alignment: .top, spacing: 0) {
                    StatBlock(value: RideFormat.distance(dist),
                              unit: RideFormat.distanceUnit,
                              label: "Distance")
                    Spacer(minLength: 0)
                    StatBlock(value: RideFormat.duration(dur),
                              label: "Duration",
                              alignment: .center)
                    Spacer(minLength: 0)
                    StatBlock(value: "\(corners)",
                              label: "Corners",
                              tint: color,
                              alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
