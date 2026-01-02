import SwiftUI

struct ProfileView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme
  @State private var isRefreshingElo: Bool = false
  @State private var trends: HealthTrendsSnapshot?
  @State private var isLoadingTrends: Bool = false
  @State private var showEditProfile: Bool = false
  @State private var showFriends: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        header
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.l)

        DSSectionHeaderRow(title: "Fitness ELO", systemImage: "gauge.with.dots.needle.67percent")

        FitnessEloCard(store: store, isRefreshing: $isRefreshingElo)
          .padding(.horizontal, DS.Spacing.xl)

        DSSectionHeaderRow(title: "Health stats", systemImage: "heart.text.square")

        VStack(spacing: DS.Spacing.m) {
          HealthStatCard(title: "Steps (today)", value: formatInt(stepsToday), subtitle: isLoadingTrends ? "Loading…" : "Today", icon: "figure.walk")
          HealthStatCard(title: "Steps (month)", value: formatCompactInt(stepsThisMonth), subtitle: "This month", icon: "calendar")
          HealthStatCard(title: "Workouts", value: formatInt(workoutsThisWeek), subtitle: "This week", icon: "figure.strengthtraining.traditional")
          HealthStatCard(title: "Sleep", value: formatDurationHoursMinutes(avgSleepLast7DaysHours), subtitle: "Avg last 7 days", icon: "bed.double")
        }
        .padding(.horizontal, DS.Spacing.xl)

        if let trends {
          DSSectionHeaderRow(title: "Trends", systemImage: "chart.line.uptrend.xyaxis")

          VStack(spacing: DS.Spacing.m) {
            TrendPanel(
              title: "Steps",
              icon: "figure.walk",
              unitCaption: "per day",
              points: trends.steps,
              valueFormatter: { formatCompactInt(Int($0.rounded())) }
            )

            TrendPanel(
              title: "Active energy",
              icon: "flame",
              unitCaption: "kcal per day",
              points: trends.activeEnergyKcal,
              valueFormatter: { formatCompactInt(Int($0.rounded())) }
            )

            TrendPanel(
              title: "Workouts",
              icon: "figure.strengthtraining.traditional",
              unitCaption: "count per day",
              points: trends.workouts,
              valueFormatter: { formatInt(Int($0.rounded())) }
            )

            TrendPanel(
              title: "Sleep",
              icon: "bed.double",
              unitCaption: "hours per day",
              points: trends.sleepHours,
              valueFormatter: { formatDurationHoursMinutes($0) }
            )
          }
          .padding(.horizontal, DS.Spacing.xl)
        }

        DSSectionHeaderRow(title: "Power-ups", systemImage: "sparkles")

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

        DSSectionHeaderRow(title: "Friend search", systemImage: "magnifyingglass")

        VStack(alignment: .leading, spacing: DS.Spacing.s) {
          HStack {
            Text("Find people")
              .font(DS.Typography.section)
            Spacer()
            Text("\(store.friends.count)")
              .font(DS.Typography.body.weight(.semibold))
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
          }

          Text("Search people, view profiles, and invite friends to games.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))

          Button {
            showFriends = true
          } label: {
            HStack {
              Image(systemName: "magnifyingglass")
              Text("Find people")
                .font(DS.Typography.body.weight(.semibold))
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .foregroundStyle(DS.Palette.text(scheme))
            .padding(.vertical, DS.Spacing.xs)
          }
          .buttonStyle(.plain)
        }
        .dsCard()
        .padding(.horizontal, DS.Spacing.xl)

        DSSectionHeaderRow(title: "Log out", systemImage: "rectangle.portrait.and.arrow.right")

        VStack(alignment: .leading, spacing: DS.Spacing.s) {
          Button(role: .destructive) {
            store.signOut()
          } label: {
            HStack {
              Text("Log out")
                .font(DS.Typography.body.weight(.semibold))
              Spacer()
              Image(systemName: "rectangle.portrait.and.arrow.right")
                .foregroundStyle(DS.Palette.danger)
            }
          }
        }
        .dsCard()
        .padding(.horizontal, DS.Spacing.xl)

        Spacer(minLength: DS.Spacing.xxl)
      }
    }
    .dsScreenBackground()
    .sheet(isPresented: $showEditProfile) {
      EditProfileSheet(store: store)
    }
    .sheet(isPresented: $showFriends) {
      FriendsView(store: store)
    }
    .task {
      await loadTrends()
      // Auto-refresh ELO at most once per 24h (manual button still available).
      _ = await FitnessEloService(store: store).refreshIfNeeded()
    }
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

        if store.profile != nil {
          Button {
            showEditProfile = true
          } label: {
            Image(systemName: "pencil")
              .font(.system(size: 15, weight: .semibold))
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
          .accessibilityLabel("Edit profile")
        }
      }

      if let profile = store.profile {
        Text(profile.visibility == .public ? "Public profile" : "Private profile")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
    }
  }

  private func loadTrends() async {
    guard store.profile != nil else { return }
    guard !isLoadingTrends else { return }
    isLoadingTrends = true
    defer { isLoadingTrends = false }

    do {
      let hk = HealthKitTrendsService()
      try await hk.requestAuthorization()
      let snap = try await hk.fetch(daysBack: 365)
      trends = snap

      // Feed step-based habits with HealthKit series (auto-tracked).
      let stepHabits = store.activeHabits.filter {
        if case .target(let metric, _, _, _) = $0.goal { return metric == .steps }
        return false
      }
      for h in stepHabits {
        store.setHealthDerivedSeries(habitID: h.id, points: snap.steps)
      }
    } catch {
      // If HealthKit isn't available/authorized, show zeros.
      trends = HealthTrendsSnapshot()
    }
  }

  private var stepsToday: Int {
    Int((trends?.steps.first?.value ?? 0).rounded())
  }

  private var stepsThisMonth: Int {
    guard let points = trends?.steps else { return 0 }
    let cal = Calendar.current
    let now = Date()
    guard let month = cal.dateInterval(of: .month, for: now) else { return 0 }
    return points
      .filter { $0.day >= cal.startOfDay(for: month.start) && $0.day < month.end }
      .reduce(0) { $0 + Int($1.value.rounded()) }
  }

  private var workoutsThisWeek: Int {
    guard let points = trends?.workouts else { return 0 }
    let cal = Calendar.current
    let now = Date()
    guard let week = cal.dateInterval(of: .weekOfYear, for: now) else { return 0 }
    return points
      .filter { $0.day >= cal.startOfDay(for: week.start) && $0.day < week.end }
      .reduce(0) { $0 + Int($1.value.rounded()) }
  }

  private var avgSleepLast7DaysHours: Double {
    guard let points = trends?.sleepHours else { return 0 }
    let last7 = Array(points.prefix(7))
    guard !last7.isEmpty else { return 0 }
    let sum = last7.reduce(0.0) { $0 + $1.value }
    return sum / Double(last7.count)
  }

  private func formatInt(_ v: Int) -> String {
    "\(v)"
  }

  private func formatCompactInt(_ v: Int) -> String {
    let absV = abs(v)
    if absV >= 1_000_000 {
      return String(format: "%.1fM", Double(v) / 1_000_000.0).replacingOccurrences(of: ".0", with: "")
    }
    if absV >= 1_000 {
      return String(format: "%.0fk", Double(v) / 1_000.0)
    }
    return "\(v)"
  }

  private func formatDurationHoursMinutes(_ hours: Double) -> String {
    let totalMinutes = max(0, Int((hours * 60).rounded()))
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    return "\(h)h \(m)m"
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

private struct TrendPanel: View {
  @Environment(\.colorScheme) private var scheme
  let title: String
  let icon: String
  let unitCaption: String
  let points: [HealthTrendPoint] // newest -> oldest
  let valueFormatter: (Double) -> String

  private var pages: [[HealthTrendPoint]] {
    stride(from: 0, to: points.count, by: 28).map { i in
      Array(points[i..<min(i + 28, points.count)])
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      HStack(spacing: DS.Spacing.m) {
        Circle()
          .fill(DS.Palette.accent.opacity(0.14))
          .frame(width: 34, height: 34)
          .overlay(
            Image(systemName: icon)
              .foregroundStyle(DS.Palette.accent)
              .font(.system(size: 14, weight: .semibold))
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(DS.Typography.section)
          Text("Swipe • 28-day panels • \(unitCaption)")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        Spacer()

        Text(valueFormatter(points.first?.value ?? 0))
          .font(DS.Typography.stat)
          .foregroundStyle(DS.Palette.text(scheme))
          .monospacedDigit()
      }

      if pages.isEmpty {
        Text("0")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      } else {
        TabView {
          ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
            TrendGrid(points: page, valueFormatter: valueFormatter)
              .padding(.vertical, 2)
              .padding(.horizontal, 2)
          }
        }
        .frame(height: 160)
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
      }
    }
    .dsCard()
  }
}

private struct TrendGrid: View {
  @Environment(\.colorScheme) private var scheme
  let points: [HealthTrendPoint] // newest -> oldest, up to 28 items
  let valueFormatter: (Double) -> String

  private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

  var body: some View {
    LazyVGrid(columns: columns, spacing: 8) {
      ForEach(points) { p in
        VStack(spacing: 4) {
          Text(p.day, format: .dateTime.day())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DS.Palette.subtext(scheme))
          Text(valueFormatter(p.value))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DS.Palette.text(scheme))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(DS.Palette.surface(scheme).opacity(0.85))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(DS.Palette.separator(scheme).opacity(0.8), lineWidth: 1)
        )
      }
    }
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

private struct FitnessEloCard: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
  @Binding var isRefreshing: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Fitness ELO")
            .font(DS.Typography.section)

          Text("0–3000 • uses historical HealthKit trends")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
        Spacer()
        if let elo = store.profile?.fitnessElo, store.profile?.hasFitnessTracker == true {
          Text("\(elo)")
            .font(DS.Typography.stat)
            .monospacedDigit()
        } else {
          Text("—")
            .font(DS.Typography.stat)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }

      if store.profile?.hasFitnessTracker != true {
        Text("Requires a fitness tracker. Enable “Fitness tracker” to compute your ELO.")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      } else {
        if let ts = store.profile?.fitnessEloUpdatedAt {
          Text("Updated \(ts.formatted(date: .abbreviated, time: .shortened))")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        } else {
          Text("Not computed yet.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        if let elo = store.profile?.fitnessElo {
          let range = FitnessEloService(store: store).recommendedMatchRange(elo: elo)
          Text("Matchmaking target: \(range.lowerBound)–\(range.upperBound)")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        Button {
          Task {
            isRefreshing = true
            _ = await FitnessEloService(store: store).refresh()
            isRefreshing = false
          }
        } label: {
          HStack {
            if isRefreshing {
              ProgressView().tint(DS.Palette.accent)
            }
            Text(isRefreshing ? "Updating…" : "Update Fitness ELO")
              .frame(maxWidth: .infinity)
              .padding(.vertical, DS.Spacing.s)
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Palette.accent)
        .disabled(isRefreshing)
        .padding(.top, DS.Spacing.s)
      }
    }
    .dsCard()
  }
}

#Preview("Profile") {
  let store = AppStore(kv: InMemoryStore())
  store.account = Account(userID: "preview@example.com", email: "preview@example.com", username: "jordan", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Jordan",
    handle: "jordan",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    hasFitnessTracker: true,
    fitnessElo: 1820,
    fitnessEloUpdatedAt: .now,
    inventory: UserInventory(quantities: [.pointsBoost12x: 3, .enemyPoints08x: 2, .freezeTime1h: 1, .unoReverseDebuffs: 0]),
    createdAt: .now,
    updatedAt: .now
  )
  return ProfileView(store: store)
}

