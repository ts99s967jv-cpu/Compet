import SwiftUI

struct DSSectionHeaderRow: View {
  @Environment(\.colorScheme) private var scheme
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: DS.Spacing.s) {
      Image(systemName: systemImage)
        .foregroundStyle(DS.Palette.accent)
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 18)
      Text(title)
        .font(DS.Typography.section)
        .foregroundStyle(DS.Palette.text(scheme))
      Spacer(minLength: 0)
    }
    .padding(.horizontal, DS.Spacing.xl)
    .padding(.top, DS.Spacing.l)
  }
}

