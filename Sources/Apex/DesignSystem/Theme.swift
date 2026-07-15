import SwiftUI

// MARK: - Theme
//
// The SINGLE SOURCE OF TRUTH for every design token in Apex.
// Maps 1:1 to docs/DESIGN_SYSTEM.md. Views consume these tokens and NEVER
// hardcode color/size/padding/font literals. To restyle the app, edit here.
//
// Organized as: Color, Typography, Spacing, Radius, Elevation, Motion.

public enum Theme {

    // MARK: Color

    public enum Palette {
        // Canvas — deep, never flat. Background is always the gradient.
        public static let canvasTop     = Color(hex: 0x0E1014)
        public static let canvasBottom  = Color(hex: 0x16181D)
        public static let surface       = Color(hex: 0x1C1F26)
        public static let surfaceRaised = Color(hex: 0x242832)
        public static let surfaceStroke = Color.white.opacity(0.08)

        // Ink
        public static let inkPrimary   = Color(hex: 0xF5F7FA)
        public static let inkSecondary = Color(hex: 0xAEB4C0)
        public static let inkTertiary  = Color(hex: 0x6E7480)
        public static let inkInverse   = Color(hex: 0x0E1014)

        // Accent — "Ignition". Scarce: primary action, live state, hero stat.
        public static let accent     = Color(hex: 0xFF6B2C)
        public static let accentHi   = Color(hex: 0xFF8A4F)
        public static let accentGlow = Color(hex: 0xFF6B2C).opacity(0.35)

        // Semantic
        public static let speed     = Color(hex: 0x38D6B0)
        public static let elevation = Color(hex: 0xC08CFF)
        public static let danger    = Color(hex: 0xFF4D4D)
        public static let success   = Color(hex: 0x3DDC84)
    }

    // The app background gradient ("garage at night").
    public static var canvas: LinearGradient {
        LinearGradient(
            colors: [Palette.canvasTop, Palette.canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // The accent gradient (primary buttons, hero accents).
    public static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.accentHi, Palette.accent],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Per-ride identity color (our "Transit line color").
    // Deterministic from a stable string (ride id) so a ride always looks the
    // same. Rich saturation, high brightness → glows on the dark canvas.
    // Rejects a dull yellow-green "mud" band so no ride looks washed out.
    public static func routeColor(for id: String) -> Color {
        var hasher = Hasher()
        hasher.combine(id)
        let raw = UInt32(truncatingIfNeeded: hasher.finalize()) &* 2654435761
        var hue = Double(raw % 360) / 360.0
        // Nudge out of the mud band (hue ~0.11–0.19 = dull yellow-green).
        if hue > 0.11 && hue < 0.19 { hue += 0.12 }
        return Color(hue: hue, saturation: 0.72, brightness: 0.95)
    }

    // MARK: Typography
    //
    // Hierarchy via aggressive weight+size contrast. Big things BIG, small small.

    public enum Font {
        public static let displayXL   = SwiftUI.Font.system(size: 48, weight: .bold).width(.standard)
        public static let display     = SwiftUI.Font.system(size: 34, weight: .bold)
        public static let titleL      = SwiftUI.Font.system(size: 28, weight: .bold)
        public static let title       = SwiftUI.Font.system(size: 22, weight: .semibold)
        public static let body        = SwiftUI.Font.system(size: 17, weight: .regular)
        public static let bodyEmphasis = SwiftUI.Font.system(size: 17, weight: .semibold)
        public static let stat        = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let label       = SwiftUI.Font.system(size: 13, weight: .medium)
        public static let caption     = SwiftUI.Font.system(size: 12, weight: .regular)
        public static let mono        = SwiftUI.Font.system(size: 15, weight: .medium).monospaced()
    }

    // Letter spacing (tracking) tokens — applied via .tracking()
    public enum Tracking {
        public static let displayXL: CGFloat = -1.0
        public static let display: CGFloat   = -0.5
        public static let titleL: CGFloat    = -0.4
        public static let title: CGFloat     = -0.2
        public static let label: CGFloat     = 0.3
    }

    // MARK: Spacing (8pt grid)

    public enum Space {
        public static let s1: CGFloat  = 4
        public static let s2: CGFloat  = 8
        public static let s3: CGFloat  = 12
        public static let s4: CGFloat  = 16
        public static let s5: CGFloat  = 20
        public static let s6: CGFloat  = 24
        public static let s8: CGFloat  = 32
        public static let s10: CGFloat = 40

        public static let screenInset: CGFloat        = 16
        public static let primaryButtonHeight: CGFloat = 58
        public static let touchMin: CGFloat           = 44
    }

    // MARK: Radius

    public enum Radius {
        public static let card: CGFloat    = 20
        public static let cardSm: CGFloat  = 14
        public static let button: CGFloat  = 16
        public static let pill: CGFloat    = 999
        public static let hairline: CGFloat = 1
    }

    // MARK: Elevation (shadow specs)

    public struct Shadow: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    public enum Elevation {
        public static let e1 = Shadow(color: .black.opacity(0.20), radius: 8,  x: 0, y: 2)
        public static let e2 = Shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 6)
        public static let accent = Shadow(color: Palette.accentGlow, radius: 24, x: 0, y: 4)
    }

    // MARK: Motion (springs — physics, not animation)

    public enum Motion {
        public static let snappy = Animation.spring(response: 0.34, dampingFraction: 0.82)
        public static let smooth = Animation.spring(response: 0.55, dampingFraction: 0.90)
    }
}

// MARK: - Color hex init

extension Color {
    /// 0xRRGGBB integer initializer (sRGB, opaque).
    public init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - View sugar for applying tokens

extension View {
    /// Apply a Theme.Shadow token.
    public func themeShadow(_ s: Theme.Shadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}
