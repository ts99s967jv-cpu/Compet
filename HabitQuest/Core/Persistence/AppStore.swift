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
  }

  func signOut() {
    account = nil
    profile = nil
    friends = []
    invites = []
    clans = []
    clanInvites = []
    clanBattles = []
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

