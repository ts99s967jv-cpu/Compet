import Foundation

#if canImport(Supabase)
import Supabase

/// Supabase implementation.
///
/// Schema assumptions (you'll create these in Supabase):
/// - `profiles` table keyed by `id` == auth.users.id (uuid)
/// - `friend_requests`, `friendships`
/// - `public_games`, `public_game_players`
@MainActor
final class SupabaseBackendClient: BackendClient {
  private let client: SupabaseClient

  init() {
    guard let url = BackendConfig.supabaseURL, let key = BackendConfig.supabaseAnonKey else {
      // Dummy client; `isAvailable` will be false and calls should be avoided.
      self.client = SupabaseClient(supabaseURL: URL(string: "https://invalid.local")!, supabaseKey: "invalid")
      return
    }
    self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
  }

  var isAvailable: Bool { BackendConfig.isSupabaseConfigured }

  var currentUserID: String? {
    client.auth.currentUser?.id.uuidString
  }

  // MARK: Auth

  func signUp(email: String, password: String) async throws -> String {
    let res = try await client.auth.signUp(email: email, password: password)
    return res.user.id.uuidString
  }

  func signIn(email: String, password: String) async throws -> String {
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.id.uuidString
  }

  func signOut() async {
    try? await client.auth.signOut()
  }

  // MARK: Profile

  private struct ProfileRow: Codable {
    var id: UUID
    var display_name: String
    var handle: String
    var age: Int
    var gender: String
    var fitness_level: String
    var visibility: String
    var has_fitness_tracker: Bool
    var fitness_elo: Int?
    var fitness_elo_updated_at: Date?
    var inventory: [String: Int]
    var created_at: Date
    var updated_at: Date
  }

  func fetchMyProfile() async throws -> UserProfile? {
    guard let uid = client.auth.currentUser?.id else { return nil }
    let rows: [ProfileRow] = try await client
      .from("profiles")
      .select()
      .eq("id", value: uid.uuidString)
      .limit(1)
      .execute()
      .value

    guard let row = rows.first else { return nil }
    return mapProfile(row)
  }

  func upsertMyProfile(_ profile: UserProfile) async throws {
    guard let uid = client.auth.currentUser?.id else { return }
    let inv: [String: Int] = Dictionary(
      uniqueKeysWithValues: profile.inventory.quantities.map { ($0.key.rawValue, $0.value) }
    )
    let row = ProfileRow(
      id: uid,
      display_name: profile.displayName,
      handle: profile.handle,
      age: profile.age,
      gender: profile.gender.rawValue,
      fitness_level: profile.fitnessLevel.rawValue,
      visibility: profile.visibility.rawValue,
      has_fitness_tracker: profile.hasFitnessTracker,
      fitness_elo: profile.fitnessElo,
      fitness_elo_updated_at: profile.fitnessEloUpdatedAt,
      inventory: inv,
      created_at: profile.createdAt,
      updated_at: profile.updatedAt
    )

    _ = try await client
      .from("profiles")
      .upsert(row, onConflict: "id")
      .execute()
  }

  func searchUsers(query: String) async throws -> [PublicUser] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }

    // Simple ilike search (you'll add an index on lower(handle)/lower(display_name)).
    struct PublicRow: Codable {
      var id: UUID
      var display_name: String
      var handle: String
      var visibility: String
    }

    let rows: [PublicRow] = try await client
      .from("profiles")
      .select("id,display_name,handle,visibility")
      .or("display_name.ilike.%\(q)%,handle.ilike.%\(q)%")
      .limit(30)
      .execute()
      .value

    return rows.map {
      PublicUser(
        id: $0.id.uuidString,
        displayName: $0.display_name,
        handle: $0.handle,
        visibility: ProfileVisibility(rawValue: $0.visibility) ?? .public
      )
    }
  }

  func fetchPublicUser(userID: String) async throws -> PublicUser? {
    struct PublicRow: Codable {
      var id: UUID
      var display_name: String
      var handle: String
      var visibility: String
    }

    let rows: [PublicRow] = try await client
      .from("profiles")
      .select("id,display_name,handle,visibility")
      .eq("id", value: userID)
      .limit(1)
      .execute()
      .value

    guard let r = rows.first else { return nil }
    return PublicUser(
      id: r.id.uuidString,
      displayName: r.display_name,
      handle: r.handle,
      visibility: ProfileVisibility(rawValue: r.visibility) ?? .public
    )
  }

  // MARK: Friends

  private struct FriendRequestRow: Codable {
    var id: UUID
    var from_user_id: UUID
    var to_user_id: UUID
    var status: String
    var created_at: Date
    var from_profile: ProfilePublicRow
    var to_profile: ProfilePublicRow
  }

  private struct ProfilePublicRow: Codable {
    var id: UUID
    var display_name: String
    var handle: String
    var visibility: String
  }

  func listFriendRequests() async throws -> [FriendRequest] {
    // Uses foreign table join aliases; see SQL in instructions.
    let rows: [FriendRequestRow] = try await client
      .from("friend_requests")
      .select("id,from_user_id,to_user_id,status,created_at,from_profile:profiles!friend_requests_from_user_id_fkey(id,display_name,handle,visibility),to_profile:profiles!friend_requests_to_user_id_fkey(id,display_name,handle,visibility)")
      .order("created_at", ascending: false)
      .execute()
      .value

    return rows.map { r in
      FriendRequest(
        id: r.id.uuidString,
        from: PublicUser(
          id: r.from_profile.id.uuidString,
          displayName: r.from_profile.display_name,
          handle: r.from_profile.handle,
          visibility: ProfileVisibility(rawValue: r.from_profile.visibility) ?? .public
        ),
        to: PublicUser(
          id: r.to_profile.id.uuidString,
          displayName: r.to_profile.display_name,
          handle: r.to_profile.handle,
          visibility: ProfileVisibility(rawValue: r.to_profile.visibility) ?? .public
        ),
        createdAt: r.created_at,
        status: FriendRequestStatus(rawValue: r.status) ?? .pending
      )
    }
  }

  func sendFriendRequest(to userID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    struct Insert: Codable { var from_user_id: UUID; var to_user_id: UUID }
    _ = try await client
      .from("friend_requests")
      .insert(Insert(from_user_id: me, to_user_id: UUID(uuidString: userID)!))
      .execute()
  }

  func respondToFriendRequest(requestID: String, accept: Bool) async throws {
    let newStatus = accept ? "accepted" : "declined"
    _ = try await client
      .from("friend_requests")
      .update(["status": newStatus])
      .eq("id", value: requestID)
      .execute()
  }

  func listFriends() async throws -> [PublicUser] {
    // Simplest approach: query `friendships` and join the other side's profile.
    struct FriendshipRow: Codable {
      var id: UUID
      var user_id: UUID
      var friend_user_id: UUID
      var created_at: Date
      var friend_profile: ProfilePublicRow
    }

    guard let me = client.auth.currentUser?.id else { return [] }
    let rows: [FriendshipRow] = try await client
      .from("friendships")
      .select("id,user_id,friend_user_id,created_at,friend_profile:profiles!friendships_friend_user_id_fkey(id,display_name,handle,visibility)")
      .eq("user_id", value: me.uuidString)
      .order("created_at", ascending: false)
      .execute()
      .value

    return rows.map {
      PublicUser(
        id: $0.friend_profile.id.uuidString,
        displayName: $0.friend_profile.display_name,
        handle: $0.friend_profile.handle,
        visibility: ProfileVisibility(rawValue: $0.friend_profile.visibility) ?? .public
      )
    }
  }

  func removeFriend(userID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    _ = try await client
      .from("friendships")
      .delete()
      .eq("user_id", value: me.uuidString)
      .eq("friend_user_id", value: userID)
      .execute()
    _ = try await client
      .from("friendships")
      .delete()
      .eq("user_id", value: userID)
      .eq("friend_user_id", value: me.uuidString)
      .execute()
  }

  // MARK: Public games

  func listPublicGames() async throws -> [PublicGame] {
    // Robust base-table implementation (does not require `public_games_view`).
    // This fixes "games disappear after re-login" when the view/RLS isn't configured.
    guard let me = client.auth.currentUser?.id else { return [] }

    struct GameRow: Codable {
      var id: UUID
      var title: String
      var created_at: Date
      var created_by: UUID
      var visibility: String
      var is_pinned: Bool
      var is_unlimited_players: Bool
      var status: String
      var max_players: Int
      var settings: GameSettings
    }
    struct PlayerRow: Codable {
      var game_id: UUID
      var user_id: UUID
      var joined_at: Date
    }

    // 1) Public + system events (browseable)
    let browseRows: [GameRow] = try await client
      .from("public_games")
      .select()
      .or("visibility.eq.public,visibility.eq.systemEvent")
      .order("created_at", ascending: false)
      .limit(200)
      .execute()
      .value

    // 2) Games I'm in (covers private + my created games even if private)
    struct MembershipRow: Codable { var game_id: UUID }
    let memberships: [MembershipRow] = try await client
      .from("public_game_players")
      .select("game_id")
      .eq("user_id", value: me.uuidString)
      .execute()
      .value

    let myIDs = Set(memberships.map { $0.game_id.uuidString })
    let myOr = ([ "created_by.eq.\(me.uuidString)" ] + myIDs.map { "id.eq.\($0)" }).joined(separator: ",")
    let myRows: [GameRow] = try await client
      .from("public_games")
      .select()
      .or(myOr)
      .execute()
      .value

    // Merge distinct by id
    var byID: [String: GameRow] = [:]
    for r in (browseRows + myRows) {
      byID[r.id.uuidString] = r
    }
    let rows = byID.values.sorted { $0.created_at > $1.created_at }
    let gameIDs = rows.map { $0.id.uuidString }

    // Fetch players for these games
    var playerRows: [PlayerRow] = []
    if !gameIDs.isEmpty {
      let cond = gameIDs.map { "game_id.eq.\($0)" }.joined(separator: ",")
      playerRows = try await client
        .from("public_game_players")
        .select("game_id,user_id,joined_at")
        .or(cond)
        .execute()
        .value
    }

    // Fetch profiles for creators + players (no joins required)
    let creatorIDs = Set(rows.map { $0.created_by.uuidString })
    let playerIDs = Set(playerRows.map { $0.user_id.uuidString })
    let profileIDs = Array(creatorIDs.union(playerIDs))

    var profilesByID: [String: ProfilePublicRow] = [:]
    if !profileIDs.isEmpty {
      let cond = profileIDs.map { "id.eq.\($0)" }.joined(separator: ",")
      let profileRows: [ProfilePublicRow] = try await client
        .from("profiles")
        .select("id,display_name,handle,visibility")
        .or(cond)
        .execute()
        .value
      profilesByID = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id.uuidString, $0) })
    }

    let playersByGameID: [String: [PlayerRow]] = Dictionary(grouping: playerRows, by: { $0.game_id.uuidString })

    func mapUser(_ id: String) -> PublicUser {
      if let p = profilesByID[id] {
        return PublicUser(
          id: p.id.uuidString,
          displayName: p.display_name,
          handle: p.handle,
          visibility: ProfileVisibility(rawValue: p.visibility) ?? .public
        )
      }
      return PublicUser(id: id, displayName: "Unknown", handle: "", visibility: .public)
    }

    return rows.map { r in
      let gid = r.id.uuidString
      let createdBy = mapUser(r.created_by.uuidString)
      let ps = (playersByGameID[gid] ?? []).sorted { $0.joined_at < $1.joined_at }.map { pr in
        PublicGamePlayer(user: mapUser(pr.user_id.uuidString), joinedAt: pr.joined_at)
      }
      return PublicGame(
        id: gid,
        title: r.title,
        createdAt: r.created_at,
        createdBy: createdBy,
        visibility: PublicGameVisibility(rawValue: r.visibility) ?? .public,
        isPinned: r.is_pinned,
        isUnlimitedPlayers: r.is_unlimited_players,
        settings: r.settings,
        status: PublicGameStatus(rawValue: r.status) ?? .open,
        maxPlayers: r.max_players,
        players: ps
      )
    }
  }

  func createPublicGame(_ game: PublicGame) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    struct Insert: Codable {
      var id: UUID
      var title: String
      var created_by: UUID
      var visibility: String
      var is_pinned: Bool
      var is_unlimited_players: Bool
      var status: String
      var max_players: Int
      var settings: GameSettings
    }

    let gid = UUID(uuidString: game.id) ?? UUID()
    _ = try await client
      .from("public_games")
      .insert(Insert(
        id: gid,
        title: game.title,
        created_by: me,
        visibility: game.visibility.rawValue,
        is_pinned: game.isPinned,
        is_unlimited_players: game.isUnlimitedPlayers,
        status: game.status.rawValue,
        max_players: game.maxPlayers,
        settings: game.settings
      ))
      .execute()

    // Ensure creator is added as a player.
    _ = try await client
      .from("public_game_players")
      .insert(["game_id": gid.uuidString, "user_id": me.uuidString])
      .execute()
  }

  func joinPublicGame(gameID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    _ = try await client
      .from("public_game_players")
      .insert(["game_id": gameID, "user_id": me.uuidString])
      .execute()
  }

  func leavePublicGame(gameID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    _ = try await client
      .from("public_game_players")
      .delete()
      .eq("game_id", value: gameID)
      .eq("user_id", value: me.uuidString)
      .execute()
  }

  func startPublicGameNow(gameID: String) async throws {
    _ = try await client
      .from("public_games")
      .update(["status": "started"])
      .eq("id", value: gameID)
      .execute()
  }

  // MARK: Mapping

  private func mapProfile(_ row: ProfileRow) -> UserProfile {
    let quantities: [PowerUpID: Int] = row.inventory.reduce(into: [:]) { acc, kv in
      let (key, value) = kv
      guard let id = PowerUpID(rawValue: key) else { return }
      acc[id] = value
    }
    return UserProfile(
      id: row.id.uuidString,
      displayName: row.display_name,
      handle: row.handle,
      age: row.age,
      gender: Gender(rawValue: row.gender) ?? .preferNotToSay,
      fitnessLevel: FitnessLevel(rawValue: row.fitness_level) ?? .beginner,
      visibility: ProfileVisibility(rawValue: row.visibility) ?? .public,
      hasFitnessTracker: row.has_fitness_tracker,
      fitnessElo: row.fitness_elo,
      fitnessEloUpdatedAt: row.fitness_elo_updated_at,
      inventory: UserInventory(quantities: quantities),
      createdAt: row.created_at,
      updatedAt: row.updated_at
    )
  }
}

#endif

