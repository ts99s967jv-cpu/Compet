import SwiftUI

struct HabitEditSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore

  let habitID: String

  @State private var name: String = ""
  @State private var description: String = ""
  @State private var visibility: HabitVisibility = .private
  @State private var isActive: Bool = true

  @State private var target: Double = 0
  @State private var unit: String = ""
  @State private var period: HabitPeriod = .day
  @State private var metric: HabitMetric = .custom

  private var habit: Habit? {
    store.habits.first(where: { $0.id == habitID })
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Edit habit")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Details")
              .font(DS.Typography.section)

            TextField("Name", text: $name)
              .textInputAutocapitalization(.words)
              .padding(DS.Spacing.l)
              .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .fill(DS.Palette.surface(scheme))
              )
              .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .stroke(DS.Palette.separator(scheme), lineWidth: 1)
              )

            TextField("Description", text: $description, axis: .vertical)
              .lineLimit(2...4)
              .padding(DS.Spacing.l)
              .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .fill(DS.Palette.surface(scheme))
              )
              .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .stroke(DS.Palette.separator(scheme), lineWidth: 1)
              )
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Goal")
              .font(DS.Typography.section)

            if case .target = habit?.goal {
              Picker("Metric", selection: $metric) {
                ForEach(HabitMetric.allCases) { m in
                  Text(m.title).tag(m)
                }
              }
              .onChange(of: metric) { _, newValue in
                if newValue != .custom { unit = newValue.defaultUnit }
              }

              Picker("Period", selection: $period) {
                ForEach(HabitPeriod.allCases) { p in
                  Text(p.rawValue.capitalized).tag(p)
                }
              }

              HStack(spacing: DS.Spacing.m) {
                VStack(alignment: .leading, spacing: 6) {
                  Text("Target")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                  TextField("Target", value: $target, format: .number)
                    .keyboardType(.decimalPad)
                    .padding(DS.Spacing.m)
                    .background(
                      RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(DS.Palette.surface(scheme))
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(DS.Palette.separator(scheme), lineWidth: 1)
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                  Text("Unit")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                  TextField("Unit", text: $unit)
                    .textInputAutocapitalization(.never)
                    .padding(DS.Spacing.m)
                    .background(
                      RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(DS.Palette.surface(scheme))
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(DS.Palette.separator(scheme), lineWidth: 1)
                    )
                }
                .frame(width: 110)
              }
            } else {
              Text("Streak-based habit")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Visibility")
              .font(DS.Typography.section)
            Picker("Visibility", selection: $visibility) {
              ForEach(HabitVisibility.allCases) { v in
                Text(v.title).tag(v)
              }
            }
            .pickerStyle(.segmented)
            .tint(DS.Palette.accent)

            Toggle("Active", isOn: $isActive)
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          Button {
            save()
          } label: {
            Text("Save changes")
              .frame(maxWidth: .infinity)
              .padding(.vertical, DS.Spacing.m)
          }
          .buttonStyle(.borderedProminent)
          .tint(DS.Palette.accent)
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.s)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
      .onAppear { hydrate() }
    }
  }

  private func hydrate() {
    guard let habit else { return }
    name = habit.name
    description = habit.description
    visibility = habit.visibility
    isActive = habit.isActive

    switch habit.goal {
    case .streak:
      break
    case .target(let m, let u, let p, let t):
      metric = m
      unit = u
      period = p
      target = t
    }
  }

  private func save() {
    guard var habit else { return }
    habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    habit.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
    habit.visibility = visibility
    habit.isActive = isActive

    if case .target = habit.goal {
      habit.goal = .target(metric: metric, unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? metric.defaultUnit : unit, period: period, target: max(0, target))
    }

    store.updateHabit(habit)
    dismiss()
  }
}

