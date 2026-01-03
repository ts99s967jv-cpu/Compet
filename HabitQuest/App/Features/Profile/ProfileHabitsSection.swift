import SwiftUI

struct ProfileHabitsSection: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var showAdd: Bool = false
  @State private var logHabit: Habit?
  @State private var editHabit: Habit?
  @State private var showArchived: Bool = false

  private let columns = [
    GridItem(.flexible(), spacing: DS.Spacing.m),
    GridItem(.flexible(), spacing: DS.Spacing.m),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.m) {
      HStack {
        Text("Habits")
          .font(DS.Typography.section)
        Spacer()
        Button {
          showAdd = true
        } label: {
          Image(systemName: "plus")
            .foregroundStyle(DS.Palette.accent)
            .padding(10)
            .background(
              RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Palette.surface(scheme))
            )
            .overlay(
              RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.separator(scheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add habit")
      }

      LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
        ForEach(store.activeHabits) { habit in
          HabitGridCard(store: store, habit: habit)
            .onTapGesture {
              withAnimation(.easeInOut(duration: 0.25)) {
                switch habit.goal {
                case .streak:
                  store.toggleCheckInToday(habitID: habit.id)
                case .target(let metric, _, _, _):
                  // Steps are auto-tracked from HealthKit (no manual logging).
                  if metric == .steps { return }
                  logHabit = habit
                }
              }
            }
            .contextMenu {
              Button {
                editHabit = habit
              } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
              }

              if habit.behavior == .breakHabit {
                Button(role: .destructive) {
                  store.markSlipToday(habitID: habit.id)
                } label: {
                  Label("Mark slip today", systemImage: "xmark.circle")
                }
              }

              Button {
                store.setHabitActive(habit.id, isActive: false)
              } label: {
                Label("Archive", systemImage: "archivebox")
              }
            }
        }
      }

      if store.activeHabits.isEmpty {
        Text("Add habits to build streaks and track goals.")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      if !store.archivedHabits.isEmpty {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { showArchived.toggle() }
        } label: {
          HStack {
            Text("Archived")
              .font(DS.Typography.section)
              .foregroundStyle(DS.Palette.text(scheme))
            Spacer()
            Image(systemName: showArchived ? "chevron.up" : "chevron.down")
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
        }
        .buttonStyle(.plain)

        if showArchived {
          LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
            ForEach(store.archivedHabits) { habit in
              HabitGridCard(store: store, habit: habit)
                .opacity(0.65)
                .contextMenu {
                  Button {
                    store.setHabitActive(habit.id, isActive: true)
                  } label: {
                    Label("Unarchive", systemImage: "arrow.uturn.backward")
                  }
                }
            }
          }
        }
      }
    }
    .dsCard()
    .sheet(isPresented: $showAdd) {
      AddHabitFlowSheet(store: store)
    }
    .sheet(item: $logHabit) { habit in
      HabitLogProgressSheet(store: store, habit: habit)
    }
    .sheet(item: $editHabit) { habit in
      HabitEditSheet(store: store, habitID: habit.id)
    }
  }
}

private struct HabitGridCard: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
  let habit: Habit

  var body: some View {
    let streak = store.habitStreakCount(habit)
    let isCompleted = store.isHabitCompletedToday(habit)

    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      Text(habit.name)
        .font(DS.Typography.section)
        .lineLimit(2)

      Spacer(minLength: 0)

      HStack {
        HStack(spacing: 6) {
          Circle()
            .fill(DS.Palette.accent.opacity(streak > 0 ? 1 : 0.35))
            .frame(width: 8, height: 8)
          Text("\(streak)\(habit.goal.period == .week ? "w" : "d") streak")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .monospacedDigit()
        }
        Spacer()
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isCompleted ? DS.Palette.accent : DS.Palette.accent.opacity(0.25))
          .contentTransition(.symbolEffect(.replace))
      }

      if case .target(let metric, let unit, _, let target) = habit.goal {
        let progress = store.habitProgressInCurrentPeriod(habit) ?? 0
        if metric == .steps {
          Text("\(format(progress)) / \(format(target)) \(unit) • Auto")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .monospacedDigit()
        } else {
          Text("\(format(progress)) / \(format(target)) \(unit)")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .monospacedDigit()
        }
      }

      if habit.visibility == .secret {
        Text("Secret habit")
          .font(DS.Typography.caption.weight(.semibold))
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
    }
    .frame(minHeight: 92, alignment: .topLeading)
    .dsCard()
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        .fill(DS.Palette.accent.opacity(0.06))
    )
  }

  private func format(_ v: Double) -> String {
    if v.rounded(.towardZero) == v {
      return String(Int(v))
    }
    return String(format: "%.1f", v)
  }
}

