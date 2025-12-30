import Foundation

@MainActor
final class BackendFriendsService {
  private let store: AppStore
  private let backend: BackendClient

  init(store: AppStore, backend: BackendClient = Backend.shared) {
    self.store = store
    self.backend = backend
  }

  func refresh() async {
    guard backend.isAvailable else { return }
    do {
      let friends = try await backend.listFriends()
      store.friends = friends.map { Friend(user: $0, since: Date()) }
      store.friends.sort { $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending }
      store.setFriendRequests(try await backend.listFriendRequests())
      store.saveAll()
    } catch {}
  }

  func sendRequest(to userID: String) async {
    guard backend.isAvailable else { return }
    do {
      try await backend.sendFriendRequest(to: userID)
      await refresh()
    } catch {}
  }

  func accept(requestID: String) async {
    guard backend.isAvailable else { return }
    do {
      try await backend.respondToFriendRequest(requestID: requestID, accept: true)
      await refresh()
    } catch {}
  }

  func decline(requestID: String) async {
    guard backend.isAvailable else { return }
    do {
      try await backend.respondToFriendRequest(requestID: requestID, accept: false)
      await refresh()
    } catch {}
  }

  func removeFriend(userID: String) async {
    guard backend.isAvailable else { return }
    do {
      try await backend.removeFriend(userID: userID)
      await refresh()
    } catch {}
  }
}

