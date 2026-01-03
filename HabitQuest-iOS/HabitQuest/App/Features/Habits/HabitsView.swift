import SwiftUI

struct HabitsView: View {
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
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
          ForEach(store.activeHabits) { habit in
            HabitGridCard(store: store, habit: habit)
              .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                  switch habit.goal {
                  case .streak:
                    store.toggleCheckInToday(habitID: habit.id)
                  case .target:
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
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.l)

        if !store.archivedHabits.isEmpty {
          VStack(alignment: .leading, spacing: DS.Spacing.s) {
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
              .padding(.horizontal, DS.Spacing.xl)
              .padding(.top, DS.Spacing.m)
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
              .padding(.horizontal, DS.Spacing.xl)
              .padding(.top, DS.Spacing.s)
            }
          }
        }

        Spacer(minLength: DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .navigationTitle("Habits")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showAdd = true
          } label: {
            Image(systemName: "plus")
              .foregroundStyle(DS.Palette.accent)
          }
        }
      }
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

      if case .target(_, let unit, _, let target) = habit.goal {
        let progress = store.habitProgressInCurrentPeriod(habit) ?? 0
        Text("\(format(progress)) / \(format(target)) \(unit)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
          .monospacedDigit()
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

#Preview("Habits") {
  let store = AppStore(kv: InMemoryStore())
  store.account = Account(userID: "preview@example.com", email: "preview@example.com", username: "preview", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Preview",
    handle: "preview",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    hasFitnessTracker: true,
    fitnessElo: 1750,
    fitnessEloUpdatedAt: .now,
    inventory: .empty,
    createdAt: .now,
    updatedAt: .now
  )
  var water = Habit.template(.drinkWater)
  water.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 1.4
  var steps = Habit.template(.moreSteps)
  steps.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 6000
  var gym = Habit.template(.goToGym)
  gym.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 1
  let secret = Habit(kind: .custom, name: "Read 10 pages", description: "", behavior: .build, goal: .streak(period: .day), visibility: .secret)
  store.habits = [water, steps, gym, secret]
  return HabitsView(store: store)
}

