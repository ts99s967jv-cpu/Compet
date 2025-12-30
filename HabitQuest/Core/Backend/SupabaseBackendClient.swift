import Foundation

#if canImport(Supabase)
import Supabase

@MainActor
final class SupabaseBackendClient: BackendClient {
  private let client: SupabaseClient

  init() {
    guard let url = BackendConfig.supabaseURL, let key = BackendConfig.supabaseAnonKey else {
      self.client = SupabaseClient(supabaseURL: URL(string: "https://invalid.local")!, supabaseKey: "invalid")
      return
    }
    self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
  }

  var isAvailable: Bool { BackendConfig.isSupabaseConfigured }
  var currentUserID: String? { client.auth.currentUser?.id.uuidString }

  func signUp(email: String, password: String) async throws -> String {
    let res = try await client.auth.signUp(email: email, password: password)
    guard let id = res.user?.id.uuidString ?? client.auth.currentUser?.id.uuidString else {
      throw NSError(domain: "SupabaseAuth", code: 1)
    }
    return id
  }

  func signIn(email: String, password: String) async throws -> String {
    let res = try await client.auth.signIn(email: email, password: password)
    return res.user.id.uuidString
  }

  func signOut() async { try? await client.auth.signOut() }

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
    let rows: [ProfileRow] = try await client.database
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
      inventory: profile.inventory.items,
      created_at: profile.createdAt,
      updated_at: profile.updatedAt
    )
    _ = try await client.database.from("profiles").upsert(row, onConflict: "id").execute()
  }

  func searchUsers(query: String) async throws -> [PublicUser] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }
    struct PublicRow: Codable { var id: UUID; var display_name: String; var handle: String; var visibility: String }
    let rows: [PublicRow] = try await client.database
      .from("profiles")
      .select("id,display_name,handle,visibility")
      .or("display_name.ilike.%\(q)%,handle.ilike.%\(q)%")
      .limit(30)
      .execute()
      .value
    return rows.map {
      PublicUser(id: $0.id.uuidString, displayName: $0.display_name, handle: $0.handle, visibility: ProfileVisibility(rawValue: $0.visibility) ?? .public)
    }
  }

  func fetchPublicUser(userID: String) async throws -> PublicUser? {
    struct PublicRow: Codable { var id: UUID; var display_name: String; var handle: String; var visibility: String }
    let rows: [PublicRow] = try await client.database
      .from("profiles")
      .select("id,display_name,handle,visibility")
      .eq("id", value: userID)
      .limit(1)
      .execute()
      .value
    guard let r = rows.first else { return nil }
    return PublicUser(id: r.id.uuidString, displayName: r.display_name, handle: r.handle, visibility: ProfileVisibility(rawValue: r.visibility) ?? .public)
  }

  private struct ProfilePublicRow: Codable { var id: UUID; var display_name: String; var handle: String; var visibility: String }
  private struct FriendRequestRow: Codable {
    var id: UUID
    var from_user_id: UUID
    var to_user_id: UUID
    var status: String
    var created_at: Date
    var from_profile: ProfilePublicRow
    var to_profile: ProfilePublicRow
  }

  func listFriendRequests() async throws -> [FriendRequest] {
    let rows: [FriendRequestRow] = try await client.database
      .from("friend_requests")
      .select("id,from_user_id,to_user_id,status,created_at,from_profile:profiles!friend_requests_from_user_id_fkey(id,display_name,handle,visibility),to_profile:profiles!friend_requests_to_user_id_fkey(id,display_name,handle,visibility)")
      .order("created_at", ascending: false)
      .execute()
      .value
    return rows.map { r in
      FriendRequest(
        id: r.id.uuidString,
        from: PublicUser(id: r.from_profile.id.uuidString, displayName: r.from_profile.display_name, handle: r.from_profile.handle, visibility: ProfileVisibility(rawValue: r.from_profile.visibility) ?? .public),
        to: PublicUser(id: r.to_profile.id.uuidString, displayName: r.to_profile.display_name, handle: r.to_profile.handle, visibility: ProfileVisibility(rawValue: r.to_profile.visibility) ?? .public),
        createdAt: r.created_at,
        status: FriendRequestStatus(rawValue: r.status) ?? .pending
      )
    }
  }

  func sendFriendRequest(to userID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    struct Insert: Codable { var from_user_id: UUID; var to_user_id: UUID }
    _ = try await client.database.from("friend_requests").insert(Insert(from_user_id: me, to_user_id: UUID(uuidString: userID)!)).execute()
  }

  func respondToFriendRequest(requestID: String, accept: Bool) async throws {
    _ = try await client.database
      .from("friend_requests")
      .update(["status": accept ? "accepted" : "declined"])
      .eq("id", value: requestID)
      .execute()
  }

  private struct FriendshipRow: Codable {
    var id: UUID
    var user_id: UUID
    var friend_user_id: UUID
    var created_at: Date
    var friend_profile: ProfilePublicRow
  }

  func listFriends() async throws -> [PublicUser] {
    guard let me = client.auth.currentUser?.id else { return [] }
    let rows: [FriendshipRow] = try await client.database
      .from("friendships")
      .select("id,user_id,friend_user_id,created_at,friend_profile:profiles!friendships_friend_user_id_fkey(id,display_name,handle,visibility)")
      .eq("user_id", value: me.uuidString)
      .order("created_at", ascending: false)
      .execute()
      .value
    return rows.map {
      PublicUser(id: $0.friend_profile.id.uuidString, displayName: $0.friend_profile.display_name, handle: $0.friend_profile.handle, visibility: ProfileVisibility(rawValue: $0.friend_profile.visibility) ?? .public)
    }
  }

  func removeFriend(userID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    _ = try await client.database.from("friendships").delete().eq("user_id", value: me.uuidString).eq("friend_user_id", value: userID).execute()
    _ = try await client.database.from("friendships").delete().eq("user_id", value: userID).eq("friend_user_id", value: me.uuidString).execute()
  }

  func listPublicGames() async throws -> [PublicGame] {
    struct GameRow: Codable {
      var id: UUID
      var title: String
      var created_at: Date
      var visibility: String
      var is_pinned: Bool
      var is_unlimited_players: Bool
      var status: String
      var max_players: Int
      var settings: GameSettings
      var created_by_profile: ProfilePublicRow
      var players: [PlayerRow]
    }
    struct PlayerRow: Codable { var user_id: UUID; var joined_at: Date; var profile: ProfilePublicRow }

    let rows: [GameRow] = try await client.database
      .from("public_games_view")
      .select()
      .order("created_at", ascending: false)
      .execute()
      .value
    return rows.map { r in
      PublicGame(
        id: r.id.uuidString,
        title: r.title,
        createdAt: r.created_at,
        createdBy: PublicUser(id: r.created_by_profile.id.uuidString, displayName: r.created_by_profile.display_name, handle: r.created_by_profile.handle, visibility: ProfileVisibility(rawValue: r.created_by_profile.visibility) ?? .public),
        visibility: PublicGameVisibility(rawValue: r.visibility) ?? .public,
        isPinned: r.is_pinned,
        isUnlimitedPlayers: r.is_unlimited_players,
        settings: r.settings,
        status: PublicGameStatus(rawValue: r.status) ?? .open,
        maxPlayers: r.max_players,
        players: r.players.map { p in
          PublicGamePlayer(user: PublicUser(id: p.profile.id.uuidString, displayName: p.profile.display_name, handle: p.profile.handle, visibility: ProfileVisibility(rawValue: p.profile.visibility) ?? .public), joinedAt: p.joined_at)
        }
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
    _ = try await client.database.from("public_games").insert(Insert(id: gid, title: game.title, created_by: me, visibility: game.visibility.rawValue, is_pinned: game.isPinned, is_unlimited_players: game.isUnlimitedPlayers, status: game.status.rawValue, max_players: game.maxPlayers, settings: game.settings)).execute()
    _ = try await client.database.from("public_game_players").insert(["game_id": gid.uuidString, "user_id": me.uuidString]).execute()
  }

  func joinPublicGame(gameID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    _ = try await client.database.from("public_game_players").insert(["game_id": gameID, "user_id": me.uuidString]).execute()
  }

  func leavePublicGame(gameID: String) async throws {
    guard let me = client.auth.currentUser?.id else { return }
    _ = try await client.database.from("public_game_players").delete().eq("game_id", value: gameID).eq("user_id", value: me.uuidString).execute()
  }

  func startPublicGameNow(gameID: String) async throws {
    _ = try await client.database.from("public_games").update(["status": "started"]).eq("id", value: gameID).execute()
  }

  private func mapProfile(_ row: ProfileRow) -> UserProfile {
    UserProfile(
      id: row.id.uuidString,
      displayName: row.display_name,
      handle: row.handle,
      age: row.age,
      gender: Gender(rawValue: row.gender) ?? .other,
      fitnessLevel: FitnessLevel(rawValue: row.fitness_level) ?? .beginner,
      visibility: ProfileVisibility(rawValue: row.visibility) ?? .public,
      hasFitnessTracker: row.has_fitness_tracker,
      fitnessElo: row.fitness_elo,
      fitnessEloUpdatedAt: row.fitness_elo_updated_at,
      inventory: UserInventory(items: row.inventory),
      createdAt: row.created_at,
      updatedAt: row.updated_at
    )
  }
}

#endif

