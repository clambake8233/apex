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
        public static let inkSecondary = Color(hex: 0xB8BEC9)
        public static let inkTertiary  = Color(hex: 0x848B98)
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
    // same ACROSS LAUNCHES. NOTE: Swift's built-in Hasher is randomly seeded per
    // process, so we use a stable FNV-1a hash here — otherwise colors would
    // change every launch.
    //
    // We index a CURATED palette (like Transit's fixed line colors) rather than
    // compute a raw hue: every entry is hand-picked to be vivid on the dark
    // canvas and clearly distinct from its neighbors, with no dull "mud" hues.
    // A hash collision just means two rides share a good-looking color — far
    // better than a computed hue accidentally landing muddy or near-identical.
    public static let routePalette: [Color] = [
        Color(hex: 0x38D6B0),  // mint
        Color(hex: 0x4FA3FF),  // sky blue
        Color(hex: 0xC08CFF),  // violet
        Color(hex: 0xFF5C8A),  // rose
        Color(hex: 0x5AE0E0),  // cyan
        Color(hex: 0xFFB020),  // amber
        Color(hex: 0x8A7CFF),  // indigo
        Color(hex: 0x54D66A),  // green
        Color(hex: 0xFF7A5C),  // coral
        Color(hex: 0xE267E2),  // magenta
    ]

    public static func routeColor(for id: String) -> Color {
        // FNV-1a 64-bit over UTF-8 bytes (stable, well-distributed).
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return routePalette[Int(hash % UInt64(routePalette.count))]
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
