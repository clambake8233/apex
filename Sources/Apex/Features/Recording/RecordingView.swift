import SwiftUI

// MARK: - RecordingView
//
// The live recording screen — where a real ride is captured. Design per
// DESIGN_PRINCIPLES: the LIVE ROUTE is the hero (full-bleed, drawing itself on a
// dark map-like canvas), a glanceable stats HUD (one big accent hero number =
// live distance), and a big bottom-anchored Start/Stop for gloved thumbs (P3).
//
// Source-agnostic via RecordingSession(provider:). On device it's fed real GPS;
// in CI/demo a SimulatedLocationProvider replays a track so the screen renders a
// live-looking ride with no GPS.

public struct RecordingView: View {
    @State private var session: RecordingSession
    private let liveColor = Theme.Palette.accent
    public var onFinish: (Ride?) -> Void = { _ in }
    public var onClose: () -> Void = {}

    public init(
        session: RecordingSession,
        onFinish: @escaping (Ride?) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        _session = State(initialValue: session)
        self.onFinish = onFinish
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Hero: the live route on a dark map-like canvas, full-bleed.
            liveRouteCanvas
                .ignoresSafeArea()

            // Top scrim + close/idle affordance.
            VStack {
                topBar
                Spacer()
            }

            // Stats HUD + primary control, bottom-anchored.
            VStack(spacing: 0) {
                Spacer()
                statsHUD
                controlBar
            }
        }
        .background(Theme.Palette.canvasTop.ignoresSafeArea())
    }

    // MARK: Live route canvas

    private var liveRouteCanvas: some View {
        GeometryReader { geo in
            ZStack {
                if session.samples.count > 1 {
                    // Real dark MapKit map with the live route on top (streets/
                    // context while riding). Camera fits the route into the upper
                    // region so the current-position marker clears the HUD.
                    LiveRouteMap(samples: session.samples, routeColor: liveColor)
                        .overlay(
                            // Subtle top-down darkening so the top bar + route
                            // read cleanly over bright map areas.
                            LinearGradient(
                                colors: [Theme.Palette.canvasTop.opacity(0.5),
                                         .clear,
                                         Theme.Palette.canvasTop.opacity(0.35)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                        )
                } else {
                    // Pre-start / acquiring state on the deep canvas.
                    Theme.canvas
                    RouteGrid().stroke(Color.white.opacity(0.035), lineWidth: 1)
                    VStack(spacing: Theme.Space.s3) {
                        Image(systemName: session.state == .idle ? "location.viewfinder" : "location.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Theme.Palette.inkTertiary)
                        Text(acquiringText)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Palette.inkTertiary)
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
                }
            }
        }
    }

    private var acquiringText: String {
        switch session.state {
        case .idle: return "Ready to ride"
        case .requestingPermission: return "Allow location to record"
        case .recording, .paused: return "Acquiring GPS…"
        case .finished: return "Ride saved"
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.Palette.surface.opacity(0.7)))
            }
            .buttonStyle(.plain)
            Spacer()
            if session.state == .recording || session.state == .paused {
                // Live REC indicator.
                HStack(spacing: Theme.Space.s2) {
                    Circle().fill(session.state == .recording ? liveColor : Theme.Palette.inkTertiary)
                        .frame(width: 8, height: 8)
                    Text(session.state == .recording ? "RECORDING" : "PAUSED")
                        .font(Theme.Font.label).tracking(Theme.Tracking.label)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                .padding(.horizontal, Theme.Space.s3)
                .padding(.vertical, Theme.Space.s2)
                .background(Capsule().fill(Theme.Palette.surface.opacity(0.7)))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)   // balance
        }
        .padding(.horizontal, Theme.Space.screenInset)
        .padding(.top, Theme.Space.s2)
    }

    // MARK: Stats HUD

    private var statsHUD: some View {
        VStack(spacing: Theme.Space.s4) {
            // Hero: live distance (the one big accent number).
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(RideFormat.distance(session.distanceMeters))
                        .font(Theme.Font.displayXL)
                        .tracking(Theme.Tracking.displayXL)
                        .foregroundStyle(liveColor)
                        .monospacedDigit()
                    Text(RideFormat.distanceUnit)
                        .font(Theme.Font.title)
                        .foregroundStyle(liveColor.opacity(0.8))
                }
                Text("DISTANCE")
                    .font(Theme.Font.label).tracking(Theme.Tracking.label)
                    .foregroundStyle(Theme.Palette.inkTertiary)
            }

            // Supporting trio: time · current speed · top speed.
            HStack(spacing: 0) {
                hudStat(RideFormat.clock(session.elapsed), "TIME", tint: Theme.Palette.inkPrimary, mono: true)
                Divider().frame(height: 34).overlay(Theme.Palette.surfaceStroke)
                hudStat(RideFormat.speed(session.currentSpeed), "KM/H", tint: Theme.Palette.speed)
                Divider().frame(height: 34).overlay(Theme.Palette.surfaceStroke)
                hudStat(RideFormat.speed(session.topSpeed), "TOP", tint: Theme.Palette.inkPrimary)
            }
        }
        .padding(.vertical, Theme.Space.s5)
        .padding(.horizontal, Theme.Space.s6)
        .frame(maxWidth: .infinity)
        .background(
            // Frosted, near-opaque card. Over a REAL map the base was showing
            // through at 0.86 (map labels ghosting behind the stats). Layer a
            // blur material UNDER an opaque surface fill so no map content bleeds
            // through, while keeping a premium translucent-glass read.
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.Palette.surface.opacity(0.97))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.surfaceStroke, lineWidth: Theme.Radius.hairline)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .padding(.horizontal, Theme.Space.screenInset)
    }

    private func hudStat(_ value: String, _ label: String, tint: Color, mono: Bool = false) -> some View {
        VStack(spacing: Theme.Space.s1) {
            Text(value)
                .font(mono ? Theme.Font.mono : Theme.Font.stat)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.label).tracking(Theme.Tracking.label)
                .foregroundStyle(Theme.Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Control bar (Start / Pause+Stop)

    private var controlBar: some View {
        Group {
            switch session.state {
            case .idle, .requestingPermission, .finished:
                bigButton(title: "Start Ride", icon: "record.circle",
                          fill: AnyShapeStyle(Theme.accentGradient),
                          fg: Theme.Palette.inkInverse) {
                    session.startOrRequest()
                }
            case .recording:
                HStack(spacing: Theme.Space.s3) {
                    secondaryControl(icon: "pause.fill", title: "Pause") { session.pause() }
                    bigButton(title: "Finish", icon: "stop.fill",
                              fill: AnyShapeStyle(Theme.Palette.danger),
                              fg: Theme.Palette.inkPrimary) {
                        onFinish(session.finish())
                    }
                }
            case .paused:
                HStack(spacing: Theme.Space.s3) {
                    secondaryControl(icon: "play.fill", title: "Resume") { session.resume() }
                    bigButton(title: "Finish", icon: "stop.fill",
                              fill: AnyShapeStyle(Theme.Palette.danger),
                              fg: Theme.Palette.inkPrimary) {
                        onFinish(session.finish())
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Space.screenInset)
        .padding(.top, Theme.Space.s4)
        .padding(.bottom, Theme.Space.s6)
    }

    private func bigButton(title: String, icon: String, fill: AnyShapeStyle,
                           fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s2) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold))
                Text(title).font(Theme.Font.bodyEmphasis)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Space.primaryButtonHeight)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(fill))
        }
        .buttonStyle(.plain)
    }

    private func secondaryControl(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s2) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(title).font(Theme.Font.bodyEmphasis)
            }
            .foregroundStyle(Theme.Palette.inkPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Space.primaryButtonHeight)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .fill(Theme.Palette.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: Theme.Radius.hairline))
        }
        .buttonStyle(.plain)
    }
}
