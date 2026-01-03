import Foundation

@MainActor
protocol BackendClient {
  var isAvailable: Bool { get }
  var currentUserID: String? { get }

  func signUp(email: String, password: String) async throws -> String
  func signIn(email: String, password: String) async throws -> String
  func signOut() async

  func fetchMyProfile() async throws -> UserProfile?
  func upsertMyProfile(_ profile: UserProfile) async throws

  func searchUsers(query: String) async throws -> [PublicUser]
  func fetchPublicUser(userID: String) async throws -> PublicUser?

  func listFriendRequests() async throws -> [FriendRequest]
  func sendFriendRequest(to userID: String) async throws
  func respondToFriendRequest(requestID: String, accept: Bool) async throws
  func listFriends() async throws -> [PublicUser]
  func removeFriend(userID: String) async throws

  func listPublicGames() async throws -> [PublicGame]
  func createPublicGame(_ game: PublicGame) async throws
  func joinPublicGame(gameID: String) async throws
  func leavePublicGame(gameID: String) async throws
  func startPublicGameNow(gameID: String) async throws
  func closePublicGame(gameID: String) async throws
  func deletePublicGame(gameID: String) async throws
}

