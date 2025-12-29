import SwiftUI

struct HabitsView: View {
  @Bindable var store: AppStore

  @State private var showAdd: Bool = false

  private let columns = [
    GridItem(.flexible(), spacing: DS.Spacing.m),
    GridItem(.flexible(), spacing: DS.Spacing.m),
  ]

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
          ForEach(store.activeHabits) { habit in
            HabitGridCard(habit: habit)
              .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                  store.toggleCompleteToday(habitID: habit.id)
                }
              }
          }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.xxl)
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
        AddHabitSheet(store: store)
      }
    }
  }
}

private struct HabitGridCard: View {
  @Environment(\.colorScheme) private var scheme
  let habit: Habit

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      Text(habit.name)
        .font(DS.Typography.section)
        .lineLimit(2)

      Spacer(minLength: 0)

      HStack {
        HStack(spacing: 6) {
          Circle()
            .fill(DS.Palette.accent.opacity(habit.streakDays > 0 ? 1 : 0.35))
            .frame(width: 8, height: 8)
          Text("\(habit.streakDays)d streak")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .monospacedDigit()
        }
        Spacer()
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(DS.Palette.accent.opacity(0.18))
      }
    }
    .frame(minHeight: 92, alignment: .topLeading)
    .dsCard()
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        .fill(DS.Palette.accent.opacity(0.06))
    )
  }
}

private struct AddHabitSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var name: String = ""

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        Text("New habit")
          .font(DS.Typography.title)
          .padding(.top, DS.Spacing.l)

        TextField("Habit name", text: $name)
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

        Spacer()

        Button {
          store.addHabit(name: name)
          dismiss()
        } label: {
          Text("Add habit")
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Palette.accent)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

#Preview("Habits") {
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
    Habit(name: "Read 10 pages", streakDays: 2, lastCompletedDay: nil),
  ]
  return HabitsView(store: store)
}

