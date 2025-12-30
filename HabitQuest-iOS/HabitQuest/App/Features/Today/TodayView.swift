import SwiftUI

struct TodayView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var now: Date = Date()
  @State private var logHabit: Habit?
  @State private var selectedActiveGameID: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        header

        progressCard

        let breakHabits = store.activeHabits.filter { $0.behavior == .breakHabit }
        if !breakHabits.isEmpty {
          Text("Break habits")
            .dsSectionHeader()

          VStack(spacing: DS.Spacing.m) {
            ForEach(breakHabits) { habit in
              HabitTodayCard(
                store: store,
                habit: habit,
                now: now,
                logTapped: { logHabit = habit }
              )
            }
          }
          .padding(.horizontal, DS.Spacing.xl)
        }

        Text("Today’s habits")
          .dsSectionHeader()

        VStack(spacing: DS.Spacing.m) {
          let buildHabits = store.activeHabits.filter { $0.behavior != .breakHabit }
          if store.activeHabits.isEmpty {
            emptyState
          } else if buildHabits.isEmpty {
            Text("You only have break habits right now.")
              .font(DS.Typography.body)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .dsCard()
          } else {
            ForEach(buildHabits) { habit in
              HabitTodayCard(
                store: store,
                habit: habit,
                now: now,
                logTapped: { logHabit = habit }
              )
            }
          }
        }
        .padding(.horizontal, DS.Spacing.xl)

        Text("Running games")
          .dsSectionHeader()

        VStack(spacing: DS.Spacing.m) {
          let running = store.activeGames.filter { $0.status == .active }
          if running.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("No active games")
                .font(DS.Typography.section)
              Text("Join or start a game from Competitions.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .dsCard()
          } else {
            ForEach(running) { game in
              ActiveGameCard(game: game) {
                selectedActiveGameID = game.id
              }
            }
          }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xxl)
      }
      .padding(.top, DS.Spacing.l)
    }
    .dsScreenBackground()
    .onAppear {
      // Seed a few habits for first-run UI (only if empty).
      if store.habits.isEmpty {
        store.addTemplateHabit(.drinkWater)
        store.addTemplateHabit(.moreSteps)
        _ = store.addCustomHabit(
          name: "Meditation",
          description: "A short session to reset.",
          behavior: .build,
          goal: .streak(period: .day),
          visibility: .private
        )
      }
    }
    .sheet(item: $logHabit) { habit in
      HabitLogProgressSheet(store: store, habit: habit)
    }
    .sheet(item: Binding(
      get: { selectedActiveGameID.map { IdentifiedID(id: $0) } },
      set: { selectedActiveGameID = $0?.id }
    )) { item in
      ActiveGameDetailSheet(store: store, gameID: item.id)
    }
    .task { await refreshStepHabits() }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text("Today")
        .font(DS.Typography.title)
        .padding(.horizontal, DS.Spacing.xl)

      Text("Stay consistent. Small wins add up.")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Palette.subtext(scheme))
        .padding(.horizontal, DS.Spacing.xl)
    }
  }

  private var progressCard: some View {
    HStack(spacing: DS.Spacing.l) {
      ProgressRing(progress: store.todayProgressFraction(now: now))
        .frame(width: 78, height: 78)

      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Daily progress")
          .font(DS.Typography.section)

        let completed = store.activeHabits.filter { store.isHabitCompletedToday($0, now: now) }.count
        let total = store.activeHabits.count
        Text("\(completed) of \(total) complete")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      Spacer()
    }
    .dsCard()
    .padding(.horizontal, DS.Spacing.xl)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      Text("No habits yet")
        .font(DS.Typography.section)
      Text("Add a habit in your Profile to start building your streaks.")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Palette.subtext(scheme))
    }
    .dsCard()
  }

  private func refreshStepHabits() async {
    let stepHabits = store.activeHabits.filter {
      if case .target(let metric, _, _, _) = $0.goal { return metric == .steps }
      return false
    }
    guard !stepHabits.isEmpty else { return }

    do {
      let hk = HealthKitStepSeriesService()
      try await hk.requestAuthorization()
      let points = try await hk.fetchDailySteps(daysBack: 60, now: now)
      for h in stepHabits {
        store.setHealthDerivedSeries(habitID: h.id, points: points)
      }
    } catch {
      // Leave derived series empty; UI will show 0.
    }
  }
}

private struct ProgressRing: View {
  @Environment(\.colorScheme) private var scheme
  let progress: Double

  var body: some View {
    ZStack {
      Circle()
        .stroke(DS.Palette.separator(scheme), lineWidth: 10)

      Circle()
        .trim(from: 0, to: max(0, min(1, progress)))
        .stroke(
          DS.Palette.accent,
          style: StrokeStyle(lineWidth: 10, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.35), value: progress)

      Text("\(Int((progress * 100).rounded()))%")
        .font(DS.Typography.caption.weight(.semibold))
        .foregroundStyle(DS.Palette.subtext(scheme))
        .monospacedDigit()
    }
  }
}

private struct HabitTodayCard: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
  let habit: Habit
  let now: Date
  let logTapped: () -> Void

  var body: some View {
    let isCompleted = store.isHabitCompletedToday(habit, now: now)
    let streak = store.habitStreakCount(habit, now: now)

    HStack(spacing: DS.Spacing.m) {
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(habit.name)
          .font(DS.Typography.section)

        HStack(spacing: DS.Spacing.s) {
          HStack(spacing: 6) {
            Image(systemName: "flame.fill")
              .font(.caption)
              .foregroundStyle(DS.Palette.accent.opacity(streak > 0 ? 1 : 0.35))
            Text("\(streak)\(habit.goal.period == .week ? "w" : "d")")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
          }

          Text(isCompleted ? "Completed" : "Not yet")
            .font(DS.Typography.caption)
            .foregroundStyle(isCompleted ? DS.Palette.accent : DS.Palette.subtext(scheme))

          if habit.visibility == .secret {
            Text("Secret")
              .font(DS.Typography.caption.weight(.semibold))
              .foregroundStyle(DS.Palette.subtext(scheme))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                Capsule(style: .continuous).fill(DS.Palette.separator(scheme).opacity(0.9))
              )
          }
        }

        if case .target(_, let unit, let period, let target) = habit.goal {
          let progress = store.habitProgressInCurrentPeriod(habit, now: now) ?? 0
          ProgressView(value: min(1, progress / max(0.0001, target))) {
            EmptyView()
          }
          .tint(DS.Palette.accent)
          .frame(maxWidth: 180)

          Text("\(format(progress)) / \(format(target)) \(unit)")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .monospacedDigit()
        }
      }

      Spacer()

      actionButton(isCompleted: isCompleted)
    }
    .dsCard()
    .animation(.easeInOut(duration: 0.25), value: isCompleted)
  }

  @ViewBuilder
  private func actionButton(isCompleted: Bool) -> some View {
    switch habit.goal {
    case .streak:
      Button {
        withAnimation(.easeInOut(duration: 0.25)) {
          store.toggleCheckInToday(habitID: habit.id, now: now)
        }
      } label: {
        ZStack {
          Circle()
            .fill(DS.Palette.accent.opacity(isCompleted ? 1 : 0.18))
            .frame(width: 42, height: 42)
          Image(systemName: isCompleted ? "checkmark" : "circle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isCompleted ? DS.Palette.background(scheme) : DS.Palette.accent)
            .contentTransition(.symbolEffect(.replace))
        }
      }
      .buttonStyle(.plain)

    case .target:
      if case .target(let metric, _, _, _) = habit.goal, metric == .steps {
        // Auto-tracked from HealthKit
        ZStack {
          Circle()
            .fill(DS.Palette.accent.opacity(0.12))
            .frame(width: 42, height: 42)
          Image(systemName: "waveform.path.ecg")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DS.Palette.accent.opacity(0.9))
        }
        .accessibilityLabel("Tracked automatically")
      } else {
        Button {
          logTapped()
        } label: {
          ZStack {
            Circle()
              .fill(DS.Palette.accent.opacity(0.18))
              .frame(width: 42, height: 42)
            Image(systemName: "plus")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(DS.Palette.accent)
          }
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func format(_ v: Double) -> String {
    if v.rounded(.towardZero) == v {
      return String(Int(v))
    }
    return String(format: "%.1f", v)
  }
}

#Preview("Today • Light") {
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
  water.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 1.2
  var steps = Habit.template(.moreSteps)
  steps.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 8420
  var med = Habit(kind: .custom, name: "Meditation", description: "10 minutes", behavior: .build, goal: .streak(period: .day), visibility: .secret)
  med.completedDayKeys.insert(Habit.dayKey(for: .now, calendar: .current))
  store.habits = [water, steps, med]
  return TodayView(store: store)
}

#Preview("Today • Dark") {
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
  water.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 1.2
  var steps = Habit.template(.moreSteps)
  steps.progressByDayKey[Habit.dayKey(for: .now, calendar: .current)] = 8420
  var med = Habit(kind: .custom, name: "Meditation", description: "10 minutes", behavior: .build, goal: .streak(period: .day), visibility: .secret)
  med.completedDayKeys.insert(Habit.dayKey(for: .now, calendar: .current))
  store.habits = [water, steps, med]
  return TodayView(store: store)
    .preferredColorScheme(.dark)
}

