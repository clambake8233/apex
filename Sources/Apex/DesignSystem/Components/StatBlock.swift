import SwiftUI

// MARK: - StatBlock
//
// A single trophy stat: big value + small uppercase label, optional unit and
// tint. Used on cards and the detail screen. Value uses monospaced digits so
// rows of stats align crisply (DESIGN_SYSTEM typography).

public struct StatBlock: View {
    public let value: String
    public let unit: String?
    public let label: String
    public var tint: Color = Theme.Palette.inkPrimary
    public var alignment: HorizontalAlignment = .leading

    public init(
        value: String,
        unit: String? = nil,
        label: String,
        tint: Color = Theme.Palette.inkPrimary,
        alignment: HorizontalAlignment = .leading
    ) {
        self.value = value
        self.unit = unit
        self.label = label
        self.tint = tint
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: Theme.Space.s1) {
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
                .font(Theme.Font.label)
                .tracking(Theme.Tracking.label)
                .foregroundStyle(Theme.Palette.inkTertiary)
        }
        .frame(maxWidth: alignment == .center ? .infinity : nil,
               alignment: frameAlignment)
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}

// MARK: - ApexCard
//
// The elevated surface container. Rounded, floating (shadow, not lines), with a
// subtle stroke. This is the "beautiful object" a ride lives in (Principle P2).

public struct ApexCard<Content: View>: View {
    private let content: Content
    public var padding: CGFloat = Theme.Space.s5

    public init(padding: CGFloat = Theme.Space.s5, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
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
}

// MARK: - Pill

public struct Pill: View {
    public let text: String
    public var systemImage: String?
    public var tint: Color = Theme.Palette.inkSecondary

    public init(_ text: String, systemImage: String? = nil, tint: Color = Theme.Palette.inkSecondary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: Theme.Space.s1) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(Theme.Font.label)
                .tracking(Theme.Tracking.label)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Space.s3)
        .padding(.vertical, Theme.Space.s1 + 2)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
    }
}
