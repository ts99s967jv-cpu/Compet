import Foundation

@MainActor
final class FriendsService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func isFriend(userID: String) -> Bool {
    store.friends.contains { $0.user.id == userID }
  }

  /// Local prototype: "Add friend" immediately adds.
  func addFriend(_ user: PublicUser) {
    store.upsertFriend(user)
  }

  func removeFriend(userID: String) {
    store.removeFriend(userID: userID)
  }
}

