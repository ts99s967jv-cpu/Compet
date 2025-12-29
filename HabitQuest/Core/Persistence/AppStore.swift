import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
  private enum Keys {
    static let account = "habitquest.account"
    static let profile = "habitquest.profile"
    static let theme = "habitquest.theme"
    static let friends = "habitquest.friends"
    static let invites = "habitquest.invites"
    static let clans = "habitquest.clans"
    static let clanInvites = "habitquest.clanInvites"
    static let clanBattles = "habitquest.clanBattles"
    static let habits = "habitquest.habits"
    static let publicGames = "habitquest.publicGames"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let kv: KeyValueStore

  var account: Account?
  var profile: UserProfile?
  var theme: AppTheme = .system

  var friends: [Friend] = []
  var invites: [GameInvite] = []

  var clans: [Clan] = []
  var clanInvites: [ClanInvite] = []
  var clanBattles: [ClanBattle] = []

  var habits: [Habit] = []
  var publicGames: [PublicGame] = []

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
    friends = load([Friend].self, key: Keys.friends) ?? []
    invites = load([GameInvite].self, key: Keys.invites) ?? []
    clans = load([Clan].self, key: Keys.clans) ?? []
    clanInvites = load([ClanInvite].self, key: Keys.clanInvites) ?? []
    clanBattles = load([ClanBattle].self, key: Keys.clanBattles) ?? []
    habits = load([Habit].self, key: Keys.habits) ?? []
    publicGames = load([PublicGame].self, key: Keys.publicGames) ?? []
  }

  func saveAll() {
    save(account, key: Keys.account)
    save(profile, key: Keys.profile)
    save(theme, key: Keys.theme)
    save(friends, key: Keys.friends)
    save(invites, key: Keys.invites)
    save(clans, key: Keys.clans)
    save(clanInvites, key: Keys.clanInvites)
    save(clanBattles, key: Keys.clanBattles)
    save(habits, key: Keys.habits)
    save(publicGames, key: Keys.publicGames)
  }

  func signOut() {
    account = nil
    profile = nil
    friends = []
    invites = []
    clans = []
    clanInvites = []
    clanBattles = []
    habits = []
    publicGames = []
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

  func addHabit(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    habits.insert(Habit(name: trimmed), at: 0)
    saveAll()
  }

  func setHabitActive(_ habitID: String, isActive: Bool) {
    guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
    habits[idx].isActive = isActive
    saveAll()
  }

  func isHabitCompletedToday(_ habit: Habit, calendar: Calendar = .current, now: Date = Date()) -> Bool {
    guard let day = habit.lastCompletedDay else { return false }
    return calendar.isDate(day, inSameDayAs: now)
  }

  /// Toggles completion for today and updates streak.
  func toggleCompleteToday(habitID: String, calendar: Calendar = .current, now: Date = Date()) {
    guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
    var h = habits[idx]

    let today = calendar.startOfDay(for: now)

    if let last = h.lastCompletedDay, calendar.isDate(last, inSameDayAs: today) {
      // Uncomplete: revert lastCompletedDay; keep streak conservative (prototype).
      h.lastCompletedDay = nil
      h.streakDays = max(0, h.streakDays - 1)
    } else {
      // Complete
      if let last = h.lastCompletedDay {
        let lastDay = calendar.startOfDay(for: last)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        if let yesterday, calendar.isDate(lastDay, inSameDayAs: yesterday) {
          h.streakDays += 1
        } else {
          h.streakDays = 1
        }
      } else {
        h.streakDays = 1
      }
      h.lastCompletedDay = today
    }

    habits[idx] = h
    saveAll()
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

