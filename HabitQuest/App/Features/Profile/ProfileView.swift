import SwiftUI

struct ProfileView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        header
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.l)

        Text("Health stats")
          .dsSectionHeader()

        VStack(spacing: DS.Spacing.m) {
          HealthStatCard(title: "Steps (today)", value: "8,420", subtitle: "On track", icon: "figure.walk")
          HealthStatCard(title: "Steps (month)", value: "182k", subtitle: "This month", icon: "calendar")
          HealthStatCard(title: "Workouts", value: "5", subtitle: "This week", icon: "figure.strengthtraining.traditional")
          HealthStatCard(title: "Sleep", value: "7h 18m", subtitle: "Avg last 7 days", icon: "bed.double")
        }
        .padding(.horizontal, DS.Spacing.xl)

        Text("Appearance")
          .dsSectionHeader()

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

        Text("Power-ups")
          .dsSectionHeader()

        VStack(spacing: DS.Spacing.m) {
          if let profile = store.profile {
            InventoryCard(store: store, profile: profile)
              .padding(.horizontal, DS.Spacing.xl)
          } else {
            Text("Sign in to manage your profile.")
              .font(DS.Typography.body)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .padding(.horizontal, DS.Spacing.xl)
          }
        }

        Spacer(minLength: DS.Spacing.xxl)
      }
    }
    .dsScreenBackground()
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      HStack(spacing: DS.Spacing.m) {
        Circle()
          .fill(DS.Palette.accent.opacity(0.18))
          .frame(width: 56, height: 56)
          .overlay(
            Image(systemName: "person.fill")
              .foregroundStyle(DS.Palette.accent)
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(store.profile?.displayName ?? "Profile")
            .font(DS.Typography.title)
          Text(store.profile.map { "@\($0.handle)" } ?? "Not signed in")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        Spacer()
      }

      if let profile = store.profile {
        Text(profile.visibility == .public ? "Public profile" : "Private profile")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
    }
  }
}

private struct HealthStatCard: View {
  @Environment(\.colorScheme) private var scheme
  let title: String
  let value: String
  let subtitle: String
  let icon: String

  var body: some View {
    HStack(spacing: DS.Spacing.m) {
      Circle()
        .fill(DS.Palette.accent.opacity(0.14))
        .frame(width: 42, height: 42)
        .overlay(
          Image(systemName: icon)
            .foregroundStyle(DS.Palette.accent)
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
        Text(value)
          .font(DS.Typography.stat)
          .foregroundStyle(DS.Palette.text(scheme))
          .monospacedDigit()
      }

      Spacer()

      Text(subtitle)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Palette.subtext(scheme))
    }
    .dsCard()
  }
}

private struct InventoryCard: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
  let profile: UserProfile

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      HStack {
        Text("Inventory")
          .font(DS.Typography.section)
        Spacer()
        Text("Earned by winning games")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      ForEach(PowerUpID.allCases) { id in
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(id.title)
              .font(DS.Typography.body.weight(.semibold))
            Text(id.rarity.title)
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
          Spacer()
          Text("×\(profile.inventory.count(of: id))")
            .font(DS.Typography.body.weight(.semibold))
            .monospacedDigit()
        }
        if id != PowerUpID.allCases.last {
          Divider().overlay(DS.Palette.separator(scheme))
        }
      }

      Button {
        InventoryService(store: store).grantDemoPack()
      } label: {
        Text("Grant demo power-ups")
          .font(DS.Typography.body.weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, DS.Spacing.s)
      }
      .buttonStyle(.borderedProminent)
      .tint(DS.Palette.accent)
      .padding(.top, DS.Spacing.m)
    }
    .dsCard()
  }
}

#Preview("Profile") {
  let store = AppStore(kv: InMemoryStore())
  store.account = Account(appleUserID: "preview", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Jordan",
    handle: "jordan",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    inventory: UserInventory(quantities: [.pointsBoost12x: 3, .enemyPoints08x: 2, .freezeTime1h: 1, .unoReverseDebuffs: 0]),
    createdAt: .now,
    updatedAt: .now
  )
  return ProfileView(store: store)
}

