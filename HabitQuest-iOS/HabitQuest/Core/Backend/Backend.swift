import Foundation

@MainActor
enum Backend {
  static let shared: BackendClient = {
    guard BackendConfig.hasSupabaseSDK else { return LocalOnlyBackendClient() }
    return SupabaseBackendClient()
  }()
}

@MainActor
final class LocalOnlyBackendClient: BackendClient {
  var isAvailable: Bool { false }
  var currentUserID: String? { nil }

  func signUp(email: String, password: String) async throws -> String { throw NSError(domain: "Backend", code: 1) }
  func signIn(email: String, password: String) async throws -> String { throw NSError(domain: "Backend", code: 1) }
  func signOut() async {}

  func fetchMyProfile() async throws -> UserProfile? { nil }
  func upsertMyProfile(_ profile: UserProfile) async throws {}

  func searchUsers(query: String) async throws -> [PublicUser] { [] }
  func fetchPublicUser(userID: String) async throws -> PublicUser? { nil }

  func listFriendRequests() async throws -> [FriendRequest] { [] }
  func sendFriendRequest(to userID: String) async throws {}
  func respondToFriendRequest(requestID: String, accept: Bool) async throws {}
  func listFriends() async throws -> [PublicUser] { [] }
  func removeFriend(userID: String) async throws {}

  func listPublicGames() async throws -> [PublicGame] { [] }
  func createPublicGame(_ game: PublicGame) async throws {}
  func joinPublicGame(gameID: String) async throws {}
  func leavePublicGame(gameID: String) async throws {}
  func startPublicGameNow(gameID: String) async throws {}
}

