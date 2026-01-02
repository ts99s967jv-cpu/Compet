import Foundation

@MainActor
final class BackendSyncService {
  private let store: AppStore
  private let backend: BackendClient

  init(store: AppStore) {
    self.store = store
    self.backend = Backend.shared
  }

  init(store: AppStore, backend: BackendClient) {
    self.store = store
    self.backend = backend
  }

  func syncAll() async {
    guard backend.isAvailable else { return }
    do {
      store.profile = try await backend.fetchMyProfile()

      let friends = try await backend.listFriends()
      store.friends = friends.map { Friend(user: $0, since: Date()) }
      store.friends.sort { $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending }

      store.setFriendRequests(try await backend.listFriendRequests())

      let publicGames = try await backend.listPublicGames()
      store.publicGames = publicGames.filter { !store.hiddenPublicGameIDs.contains($0.id) }
      store.saveAll()
    } catch {}
  }
}

