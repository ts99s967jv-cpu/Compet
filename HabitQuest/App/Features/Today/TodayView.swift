import SwiftUI

struct TodayView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var now: Date = Date()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        header

        progressCard

        Text("Today’s habits")
          .dsSectionHeader()

        VStack(spacing: DS.Spacing.m) {
          if store.activeHabits.isEmpty {
            emptyState
          } else {
            ForEach(store.activeHabits) { habit in
              HabitTodayCard(
                habit: habit,
                isCompleted: store.isHabitCompletedToday(habit, now: now),
                completeTapped: {
                  withAnimation(.easeInOut(duration: 0.25)) {
                    store.toggleCompleteToday(habitID: habit.id, now: now)
                  }
                }
              )
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
        store.addHabit(name: "Take vitamins")
        store.addHabit(name: "Workout")
        store.addHabit(name: "Meditation")
      }
    }
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
      Text("Add a habit in the Habits tab to start building your streaks.")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Palette.subtext(scheme))
    }
    .dsCard()
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
  let habit: Habit
  let isCompleted: Bool
  let completeTapped: () -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.m) {
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(habit.name)
          .font(DS.Typography.section)

        HStack(spacing: DS.Spacing.s) {
          HStack(spacing: 6) {
            Image(systemName: "flame.fill")
              .font(.caption)
              .foregroundStyle(DS.Palette.accent.opacity(habit.streakDays > 0 ? 1 : 0.35))
            Text("\(habit.streakDays)d")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
          }

          Text(isCompleted ? "Completed" : "Not yet")
            .font(DS.Typography.caption)
            .foregroundStyle(isCompleted ? DS.Palette.accent : DS.Palette.subtext(scheme))
        }
      }

      Spacer()

      Button(action: completeTapped) {
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
    }
    .dsCard()
    .animation(.easeInOut(duration: 0.25), value: isCompleted)
  }
}

#Preview("Today • Light") {
  let store = AppStore(kv: InMemoryStore())
  store.account = Account(appleUserID: "preview", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Preview",
    handle: "preview",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    inventory: .empty,
    createdAt: .now,
    updatedAt: .now
  )
  store.habits = [
    Habit(name: "Take vitamins", streakDays: 6, lastCompletedDay: Calendar.current.startOfDay(for: .now)),
    Habit(name: "Workout", streakDays: 3, lastCompletedDay: nil),
    Habit(name: "Meditation", streakDays: 10, lastCompletedDay: nil),
  ]
  return TodayView(store: store)
}

#Preview("Today • Dark") {
  let store = AppStore(kv: InMemoryStore())
  store.account = Account(appleUserID: "preview", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Preview",
    handle: "preview",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    inventory: .empty,
    createdAt: .now,
    updatedAt: .now
  )
  store.habits = [
    Habit(name: "Take vitamins", streakDays: 6, lastCompletedDay: Calendar.current.startOfDay(for: .now)),
    Habit(name: "Workout", streakDays: 3, lastCompletedDay: nil),
    Habit(name: "Meditation", streakDays: 10, lastCompletedDay: nil),
  ]
  return TodayView(store: store)
    .preferredColorScheme(.dark)
}

