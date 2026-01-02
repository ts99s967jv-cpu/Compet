import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
  private enum Keys {
    static let account = "habitquest.account"
    static let profile = "habitquest.profile"
    static let theme = "habitquest.theme"
    static let measurementSystem = "habitquest.measurementSystem"
    static let friends = "habitquest.friends"
    static let friendRequests = "habitquest.friendRequests"
    static let invites = "habitquest.invites"
    static let clans = "habitquest.clans"
    static let clanInvites = "habitquest.clanInvites"
    static let clanBattles = "habitquest.clanBattles"
    static let habits = "habitquest.habits"
    static let publicGames = "habitquest.publicGames"
    static let activeGames = "habitquest.activeGames"
    static let gameScores = "habitquest.gameScores"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let kv: KeyValueStore

  var account: Account?
  var profile: UserProfile?
  var theme: AppTheme = .system
  var measurementSystem: MeasurementSystem = .metric

  var friends: [Friend] = []
  var friendRequests: [FriendRequest] = []
  var invites: [GameInvite] = []

  var clans: [Clan] = []
  var clanInvites: [ClanInvite] = []
  var clanBattles: [ClanBattle] = []

  var habits: [Habit] = []
  var publicGames: [PublicGame] = []
  var activeGames: [ActiveGame] = []
  var gameScores: [GameScore] = []

  /// Ephemeral (not persisted) HealthKit-derived progress, keyed by habitID -> dayKey -> value.
  /// Used for auto-tracked habits like Steps so users don’t manually input Health data.
  var healthDerivedProgressByHabitID: [String: [String: Double]] = [:]

  init(kv: KeyValueStore = UserDefaultsStore()) {
    self.kv = kv
    decoder.dateDecodingStrategy = .iso8601
    encoder.dateEncodingStrategy = .iso8601
    load()
  }

  var isSignedIn: Bool { account != nil }
  var hasProfile: Bool { profile != nil }

  func load() {
    account = load(Account.self, key: Keys.account)
    profile = load(UserProfile.self, key: Keys.profile)
    theme = load(AppTheme.self, key: Keys.theme) ?? .system
    measurementSystem = load(MeasurementSystem.self, key: Keys.measurementSystem) ?? .metric
    friends = load([Friend].self, key: Keys.friends) ?? []
    friendRequests = load([FriendRequest].self, key: Keys.friendRequests) ?? []
    invites = load([GameInvite].self, key: Keys.invites) ?? []
    clans = load([Clan].self, key: Keys.clans) ?? []
    clanInvites = load([ClanInvite].self, key: Keys.clanInvites) ?? []
    clanBattles = load([ClanBattle].self, key: Keys.clanBattles) ?? []
    habits = load([Habit].self, key: Keys.habits) ?? []
    publicGames = load([PublicGame].self, key: Keys.publicGames) ?? []
    activeGames = load([ActiveGame].self, key: Keys.activeGames) ?? []
    gameScores = load([GameScore].self, key: Keys.gameScores) ?? []
  }

  func saveAll() {
    save(account, key: Keys.account)
    save(profile, key: Keys.profile)
    save(theme, key: Keys.theme)
    save(measurementSystem, key: Keys.measurementSystem)
    save(friends, key: Keys.friends)
    save(friendRequests, key: Keys.friendRequests)
    save(invites, key: Keys.invites)
    save(clans, key: Keys.clans)
    save(clanInvites, key: Keys.clanInvites)
    save(clanBattles, key: Keys.clanBattles)
    save(habits, key: Keys.habits)
    save(publicGames, key: Keys.publicGames)
    save(activeGames, key: Keys.activeGames)
    save(gameScores, key: Keys.gameScores)
  }

  func signOut() {
    account = nil
    profile = nil
    friends = []
    friendRequests = []
    invites = []
    clans = []
    clanInvites = []
    clanBattles = []
    habits = []
    publicGames = []
    activeGames = []
    gameScores = []
    saveAll()
  }

  // MARK: - Game scores (leaderboards)

  func upsertGameScore(_ score: GameScore) {
    if let idx = gameScores.firstIndex(where: { $0.id == score.id }) {
      gameScores[idx] = score
    } else {
      gameScores.insert(score, at: 0)
    }
    saveAll()
  }

  func gameScore(activeGameID: String, roundIndex: Int, userID: String) -> GameScore? {
    gameScores.first(where: { $0.activeGameID == activeGameID && $0.roundIndex == roundIndex && $0.userID == userID })
  }

  func setGameScores(_ scores: [GameScore]) {
    gameScores = scores
    saveAll()
  }

  func upsertFriend(_ user: PublicUser) {
    if friends.contains(where: { $0.user.id == user.id }) { return }
    friends.append(Friend(user: user, since: Date()))
    friends.sort { $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending }
    saveAll()
  }

  func removeFriend(userID: String) {
    friends.removeAll { $0.user.id == userID }
    saveAll()
  }

  func setFriendRequests(_ requests: [FriendRequest]) {
    friendRequests = requests.sorted { $0.createdAt > $1.createdAt }
    saveAll()
  }

  func addInvite(_ invite: GameInvite) {
    invites.insert(invite, at: 0)
    saveAll()
  }

  func updateInvite(_ invite: GameInvite) {
    guard let idx = invites.firstIndex(where: { $0.id == invite.id }) else { return }
    invites[idx] = invite
    saveAll()
  }

  func addClan(_ clan: Clan) {
    clans.append(clan)
    clans.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    saveAll()
  }

  func updateClan(_ clan: Clan) {
    guard let idx = clans.firstIndex(where: { $0.id == clan.id }) else { return }
    clans[idx] = clan
    clans.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    saveAll()
  }

  func addClanInvite(_ invite: ClanInvite) {
    clanInvites.insert(invite, at: 0)
    saveAll()
  }

  func updateClanInvite(_ invite: ClanInvite) {
    guard let idx = clanInvites.firstIndex(where: { $0.id == invite.id }) else { return }
    clanInvites[idx] = invite
    saveAll()
  }

  func addClanBattle(_ battle: ClanBattle) {
    clanBattles.insert(battle, at: 0)
    saveAll()
  }

  func updateClanBattle(_ battle: ClanBattle) {
    guard let idx = clanBattles.firstIndex(where: { $0.id == battle.id }) else { return }
    clanBattles[idx] = battle
    saveAll()
  }

  // MARK: - Habits

  var customHabitsCount: Int {
    habits.filter { $0.kind == .custom }.count
  }

  func addTemplateHabit(_ templateID: HabitTemplateID) {
    // Avoid duplicate template habits (one of each template).
    if habits.contains(where: { $0.templateID == templateID }) { return }
    habits.insert(Habit.template(templateID), at: 0)
    saveAll()
  }

  /// Adds a custom habit. Enforces a maximum of 3 custom habits.
  func addCustomHabit(
    name: String,
    description: String,
    behavior: HabitBehavior,
    goal: HabitGoal,
    visibility: HabitVisibility
  ) -> Bool {
    if customHabitsCount >= 3 { return false }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let habit = Habit(
      kind: .custom,
      templateID: nil,
      name: trimmed,
      description: description.trimmingCharacters(in: .whitespacesAndNewlines),
      behavior: behavior,
      goal: goal,
      visibility: visibility
    )
    habits.insert(habit, at: 0)
    saveAll()
    return true
  }

  func updateHabit(_ habit: Habit) {
    guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
    habits[idx] = habit
    saveAll()
  }

  func setHabitActive(_ habitID: String, isActive: Bool) {
    guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
    habits[idx].isActive = isActive
    saveAll()
  }

  func dayKey(for date: Date, calendar: Calendar = .current) -> String {
    Habit.dayKey(for: date, calendar: calendar)
  }

  func isHabitCompletedToday(_ habit: Habit, calendar: Calendar = .current, now: Date = Date()) -> Bool {
    let key = dayKey(for: now, calendar: calendar)
    return isHabitCompleted(habit, dayKey: key, calendar: calendar, now: now)
  }

  func habitProgressToday(_ habit: Habit, calendar: Calendar = .current, now: Date = Date()) -> Double {
    let key = dayKey(for: now, calendar: calendar)
    if let derived = healthDerivedProgressByHabitID[habit.id]?[key] {
      return derived
    }
    return habit.progressByDayKey[key] ?? 0
  }

  func habitProgressInCurrentPeriod(_ habit: Habit, calendar: Calendar = .current, now: Date = Date()) -> Double? {
    switch habit.goal {
    case .streak:
      return nil
    case .target(_, _, let period, _):
      switch period {
      case .day:
        return habitProgressToday(habit, calendar: calendar, now: now)
      case .week:
        let keys = weekDayKeys(containing: now, calendar: calendar)
        return keys.reduce(0.0) { sum, k in
          if let derived = healthDerivedProgressByHabitID[habit.id]?[k] {
            return sum + derived
          }
          return sum + (habit.progressByDayKey[k] ?? 0)
        }
      }
    }
  }

  func habitTargetValue(_ habit: Habit) -> Double? {
    switch habit.goal {
    case .streak:
      return nil
    case .target(_, _, _, let target):
      return target
    }
  }

  /// Toggles a streak-based check-in for today (or logs a gym day).
  func toggleCheckInToday(habitID: String, calendar: Calendar = .current, now: Date = Date()) {
    guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
    var h = habits[idx]
    let key = dayKey(for: now, calendar: calendar)
    if h.completedDayKeys.contains(key) {
      h.completedDayKeys.remove(key)
    } else {
      h.completedDayKeys.insert(key)
      // If this is a break-habit and they check in success, ensure today isn't marked as slip.
      h.slipDayKeys.remove(key)
    }
    habits[idx] = h
    saveAll()
  }

  /// For goal-based habits: add progress for today (e.g. water/steps). If it reaches the target, today counts as complete.
  func addProgressToday(habitID: String, amount: Double, calendar: Calendar = .current, now: Date = Date()) {
    guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
    var h = habits[idx]
    if case .target(let metric, _, let period, _) = h.goal,
       metric == .steps, period == .day {
      // Steps are auto-tracked from HealthKit (no manual input).
      return
    }
    let key = dayKey(for: now, calendar: calendar)
    let current = h.progressByDayKey[key] ?? 0
    h.progressByDayKey[key] = max(0, current + amount)
    habits[idx] = h
    saveAll()
  }

  /// Marks a slip day for break-habits (resets the streak).
  func markSlipToday(habitID: String, calendar: Calendar = .current, now: Date = Date()) {
    guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
    var h = habits[idx]
    let key = dayKey(for: now, calendar: calendar)
    h.slipDayKeys.insert(key)
    h.completedDayKeys.remove(key)
    habits[idx] = h
    saveAll()
  }

  func isHabitCompleted(_ habit: Habit, dayKey: String, calendar: Calendar = .current, now: Date = Date()) -> Bool {
    switch habit.goal {
    case .streak(let period):
      switch period {
      case .day:
        if habit.behavior == .breakHabit {
          // Consider a break-habit “complete” if they did NOT slip and/or explicitly checked in.
          return !habit.slipDayKeys.contains(dayKey) && habit.completedDayKeys.contains(dayKey)
        }
        return habit.completedDayKeys.contains(dayKey)
      case .week:
        // Week streak = week meets completion on all required days? For now treat as “any check-in” (placeholder).
        return habit.completedDayKeys.contains(dayKey)
      }
    case .target(_, _, let period, let target):
      switch period {
      case .day:
        let v = healthDerivedProgressByHabitID[habit.id]?[dayKey] ?? (habit.progressByDayKey[dayKey] ?? 0)
        return v >= target
      case .week:
        let range = weekDayKeys(containing: now, calendar: calendar)
        let sum = range.reduce(0.0) { acc, k in
          let v = healthDerivedProgressByHabitID[habit.id]?[k] ?? (habit.progressByDayKey[k] ?? 0)
          return acc + v
        }
        return sum >= target
      }
    }
  }

  /// Sets (or replaces) HealthKit-derived series for a habit.
  /// This is not persisted; it’s intended for live display and completion logic.
  func setHealthDerivedSeries(habitID: String, points: [HealthTrendPoint], calendar: Calendar = .current) {
    var map: [String: Double] = [:]
    for p in points {
      map[dayKey(for: p.day, calendar: calendar)] = max(0, p.value)
    }
    healthDerivedProgressByHabitID[habitID] = map
  }

  func habitStreakCount(_ habit: Habit, calendar: Calendar = .current, now: Date = Date()) -> Int {
    switch habit.goal {
    case .streak(let period):
      switch period {
      case .day:
        return dailyStreak(habit: habit, calendar: calendar, now: now)
      case .week:
        return weeklyStreak(habit: habit, calendar: calendar, now: now)
      }
    case .target(_, _, let period, _):
      switch period {
      case .day:
        return dailyStreak(habit: habit, calendar: calendar, now: now)
      case .week:
        return weeklyTargetStreak(habit: habit, calendar: calendar, now: now)
      }
    }
  }

  private func dailyStreak(habit: Habit, calendar: Calendar, now: Date) -> Int {
    var count = 0
    var cursor = calendar.startOfDay(for: now)
    while true {
      let key = dayKey(for: cursor, calendar: calendar)
      let ok: Bool
      if habit.behavior == .breakHabit {
        ok = !habit.slipDayKeys.contains(key) && habit.completedDayKeys.contains(key)
      } else {
        ok = isHabitCompleted(habit, dayKey: key, calendar: calendar, now: now)
      }
      if ok {
        count += 1
        guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = prev
      } else {
        break
      }
    }
    return count
  }

  private func weeklyStreak(habit: Habit, calendar: Calendar, now: Date) -> Int {
    // Week streak for check-in habits: week counts as complete if at least one completion in that week.
    var count = 0
    var weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
    while true {
      let keys = weekDayKeys(containing: weekStart, calendar: calendar)
      let hasAny = keys.contains(where: { habit.completedDayKeys.contains($0) })
      if hasAny {
        count += 1
        guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
        weekStart = prevWeek
      } else {
        break
      }
    }
    return count
  }

  private func weeklyTargetStreak(habit: Habit, calendar: Calendar, now: Date) -> Int {
    guard case .target(_, _, .week, let target) = habit.goal else { return 0 }
    var count = 0
    var cursor = now
    while true {
      guard let interval = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
      let keys = weekDayKeys(containing: interval.start, calendar: calendar)
      let sum = keys.reduce(0.0) { $0 + (habit.progressByDayKey[$1] ?? 0) }
      if sum >= target {
        count += 1
        guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: interval.start) else { break }
        cursor = prevWeek
      } else {
        break
      }
    }
    return count
  }

  private func weekDayKeys(containing date: Date, calendar: Calendar) -> [String] {
    guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
    var keys: [String] = []
    var day = interval.start
    while day < interval.end {
      keys.append(dayKey(for: day, calendar: calendar))
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }
    return keys
  }

  var activeHabits: [Habit] {
    habits.filter { $0.isActive }
  }

  func todayProgressFraction(calendar: Calendar = .current, now: Date = Date()) -> Double {
    let active = activeHabits
    guard !active.isEmpty else { return 0 }
    let completed = active.filter { isHabitCompletedToday($0, calendar: calendar, now: now) }.count
    return Double(completed) / Double(active.count)
  }

  // MARK: - Public games

  func addPublicGame(_ game: PublicGame) {
    publicGames.insert(game, at: 0)
    saveAll()
  }

  func updatePublicGame(_ game: PublicGame) {
    guard let idx = publicGames.firstIndex(where: { $0.id == game.id }) else { return }
    publicGames[idx] = game
    saveAll()
  }

  func removePublicGame(gameID: String) {
    publicGames.removeAll { $0.id == gameID }
    saveAll()
  }

  // MARK: - Active games

  func addActiveGame(_ game: ActiveGame) {
    if activeGames.contains(where: { $0.id == game.id }) { return }
    activeGames.insert(game, at: 0)
    saveAll()
  }

  func updateActiveGame(_ game: ActiveGame) {
    guard let idx = activeGames.firstIndex(where: { $0.id == game.id }) else { return }
    activeGames[idx] = game
    saveAll()
  }

  private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = kv.data(forKey: key) else { return nil }
    return try? decoder.decode(T.self, from: data)
  }

  private func save<T: Encodable>(_ value: T?, key: String) {
    guard let value else {
      kv.set(nil, forKey: key)
      return
    }
    let data = try? encoder.encode(value)
    kv.set(data, forKey: key)
  }
}

