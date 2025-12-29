import SwiftUI

/// Centralized design system inspired by Samsung Health-style calm surfaces.
enum DS {
  enum Spacing {
    static let xs: CGFloat = 6
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 18
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
  }

  enum Radius {
    static let card: CGFloat = 18
    static let pill: CGFloat = 999
  }

  enum Shadow {
    /// Subtle shadow for light mode; in dark mode we rely more on elevation by color.
    static func card(for scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
      switch scheme {
      case .dark:
        return (Color.black.opacity(0.25), 18, 10)
      default:
        return (Color.black.opacity(0.08), 16, 10)
      }
    }
  }

  enum Typography {
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let section = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let stat = Font.system(.title3, design: .rounded).weight(.semibold)
  }

  enum Palette {
    // Primary accent (health green)
    static let accent = Color(hex: 0x2ECC71)

    // Light mode
    static let lightBackground = Color.white
    static let lightSurface = Color(hex: 0xF3F5F7) // very light gray
    static let lightSeparator = Color(hex: 0xE6EAED)
    static let lightText = Color(hex: 0x0F1720)
    static let lightSubtext = Color(hex: 0x5B6772)

    // Dark mode (near-black with subtle blue-green tint)
    static let darkBackground = Color(hex: 0x071315)
    static let darkSurface = Color(hex: 0x0E1E20) // muted teal-gray
    static let darkSeparator = Color(hex: 0x163033)
    static let darkText = Color(hex: 0xE6F0F0) // avoid harsh white
    static let darkSubtext = Color(hex: 0x98ACAE)

    // Feedback
    static let danger = Color(hex: 0xE45B4A) // muted red (avoid neon)

    static func background(_ scheme: ColorScheme) -> Color {
      scheme == .dark ? darkBackground : lightBackground
    }

    static func surface(_ scheme: ColorScheme) -> Color {
      scheme == .dark ? darkSurface : lightSurface
    }

    static func separator(_ scheme: ColorScheme) -> Color {
      scheme == .dark ? darkSeparator : lightSeparator
    }

    static func text(_ scheme: ColorScheme) -> Color {
      scheme == .dark ? darkText : lightText
    }

    static func subtext(_ scheme: ColorScheme) -> Color {
      scheme == .dark ? darkSubtext : lightSubtext
    }
  }
}

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    let r = Double((hex >> 16) & 0xFF) / 255.0
    let g = Double((hex >> 8) & 0xFF) / 255.0
    let b = Double(hex & 0xFF) / 255.0
    self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
  }
}

extension View {
  func dsScreenBackground() -> some View {
    modifier(DSBackgroundModifier())
  }

  func dsCard() -> some View {
    modifier(DSCardModifier())
  }

  func dsSectionHeader() -> some View {
    modifier(DSSectionHeaderModifier())
  }
}

private struct DSBackgroundModifier: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content
      .background(DS.Palette.background(scheme))
      .foregroundStyle(DS.Palette.text(scheme))
  }
}

private struct DSCardModifier: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    let sh = DS.Shadow.card(for: scheme)
    return content
      .padding(DS.Spacing.l)
      .background(
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
          .fill(DS.Palette.surface(scheme))
      )
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
          .stroke(DS.Palette.separator(scheme), lineWidth: 1)
      )
      .shadow(color: sh.color, radius: sh.radius, x: 0, y: sh.y)
  }
}

private struct DSSectionHeaderModifier: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content
      .font(DS.Typography.section)
      .foregroundStyle(DS.Palette.text(scheme))
      .padding(.horizontal, DS.Spacing.xl)
      .padding(.top, DS.Spacing.l)
  }
}

