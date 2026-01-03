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
      let now = Date()
      let previousFriendRequestIDs = Set(store.friendRequests.map { $0.id })
      let previousInviteIDs = Set(store.invites.map { $0.id })

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
      // Apply client-side hide list (leaving a lobby removes it from your UI).
      store.publicGames = publicGames.filter { !store.hiddenPublicGameIDs.contains($0.id) }
      // Promote any started games I'm in into ActiveGames so they actually "run".
      await promoteStartedPublicGamesToActiveGames(now: now)

      // Notifications (inbox + optional local notifications)
      let notifier = NotificationsService(store: store)
      notifier.notifyNewFriendRequests(previousIDs: previousFriendRequestIDs, now: now)
      notifier.notifyNewInvites(previousIDs: previousInviteIDs, now: now)

      store.saveAll()
    } catch {
      // Keep local state if backend fails (offline / misconfigured).
    }
  }

  private func promoteStartedPublicGamesToActiveGames(now: Date) async {
    guard let meID = store.profile?.id else { return }
    let svc = ActiveGamesService(store: store)
    let sync = GameScoreSyncService(store: store)

    let candidates = store.publicGames.filter { $0.status == .started && $0.contains(userID: meID) }
    for g in candidates {
      let activeID = "ag_" + g.id
      if store.activeGames.contains(where: { $0.id == activeID }) {
        // Ensure players are up to date.
        svc.addPlayerToActiveGame(activeGameID: activeID, user: store.profile!.asPublicUser())
        continue
      }

      switch g.settings.winCondition {
      case .eliminationLastManStanding, .kingOfMonth, .kingOfYear:
        svc.startEliminationStyleGame(from: g, now: now)
      case .levelVsLevelGoal:
        svc.startLevelVsLevelGame(from: g, now: now)
      case .mostPointsAtEnd:
        svc.startMostPointsGame(from: g, now: now)
      }

      if let active = store.activeGames.first(where: { $0.id == activeID }) {
        await sync.syncMyScore(for: active, now: now)
      }
    }
  }
}

