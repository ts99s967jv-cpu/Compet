import SwiftUI

struct HabitLogProgressSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
  let habit: Habit

  @State private var amountText: String = ""

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        Text(habit.name)
          .font(DS.Typography.title)
          .padding(.top, DS.Spacing.l)

        if case .target(_, let unit, _, _) = habit.goal {
          Text("Log progress (\(unit))")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))

          TextField("Amount", text: $amountText)
            .keyboardType(.decimalPad)
            .padding(DS.Spacing.l)
            .background(
              RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Palette.surface(scheme))
            )
            .overlay(
              RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.separator(scheme), lineWidth: 1)
            )
        } else {
          Text("This habit doesn’t use numeric progress.")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        Spacer()

        Button {
          let v = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
          if v > 0 {
            store.addProgressToday(habitID: habit.id, amount: v)
          }
          dismiss()
        } label: {
          Text("Add")
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Palette.accent)
      }
      .padding(.horizontal, DS.Spacing.xl)
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
    }
  }
}

