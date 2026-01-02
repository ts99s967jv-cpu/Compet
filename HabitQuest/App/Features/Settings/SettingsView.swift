import SwiftUI

struct SettingsView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Settings")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          DSSectionHeaderRow(title: "Habits", systemImage: "checkmark.circle")
          ProfileHabitsSection(store: store)
            .padding(.horizontal, DS.Spacing.xl)

          DSSectionHeaderRow(title: "Appearance", systemImage: "circle.lefthalf.filled")
          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Theme")
              .font(DS.Typography.section)
            Picker("Theme", selection: $store.theme) {
              ForEach(AppTheme.allCases) { t in
                Text(t.title).tag(t)
              }
            }
            .pickerStyle(.segmented)
            .tint(DS.Palette.accent)
            .onChange(of: store.theme) { _, _ in store.saveAll() }
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          DSSectionHeaderRow(title: "Fitness tracker", systemImage: "checkmark.shield")
          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Toggle("Fitness tracker", isOn: Binding(
              get: { store.profile?.hasFitnessTracker ?? false },
              set: { newValue in
                store.profile?.hasFitnessTracker = newValue
                store.profile?.updatedAt = Date()
                store.saveAll()
                if let p = store.profile, Backend.shared.isAvailable {
                  Task { try? await Backend.shared.upsertMyProfile(p) }
                }
              }
            ))
            Text("Used for fair matchmaking in games that require/avoid tracker users.")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)
          .opacity(store.profile == nil ? 0.55 : 1)
          .disabled(store.profile == nil)

          DSSectionHeaderRow(title: "Measurements", systemImage: "ruler")
          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Measurement system")
              .font(DS.Typography.section)
            Picker("Measurement system", selection: $store.measurementSystem) {
              ForEach(MeasurementSystem.allCases) { m in
                Text(m.title).tag(m)
              }
            }
            .pickerStyle(.segmented)
            .tint(DS.Palette.accent)
            .onChange(of: store.measurementSystem) { _, _ in store.saveAll() }
            Text("Used for displaying distances and other units (metric vs imperial).")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
    }
  }
}

