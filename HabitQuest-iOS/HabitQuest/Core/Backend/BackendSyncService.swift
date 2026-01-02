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
      // Only overwrite auth-scoped state when we actually have a backend session.
      if backend.currentUserID != nil {
        // Profile
        if let profile = try await backend.fetchMyProfile() {
          store.profile = profile
        }

        // Social
        let friends = try await backend.listFriends()
        store.friends = friends.map { Friend(user: $0, since: Date()) }
        store.friends.sort { $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending }

        let requests = try await backend.listFriendRequests()
        store.setFriendRequests(requests)
      }

      // Games
      let publicGames = try await backend.listPublicGames()
      store.publicGames = publicGames
      store.saveAll()
    } catch {
      // Keep local state if backend fails (offline / misconfigured).
    }
  }
}

