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
      await promoteStartedPublicGamesToActiveGames(now: Date())
      store.saveAll()
    } catch {}
  }

  private func promoteStartedPublicGamesToActiveGames(now: Date) async {
    guard let meID = store.profile?.id else { return }
    let svc = ActiveGamesService(store: store)
    let sync = GameScoreSyncService(store: store)

    let candidates = store.publicGames.filter { $0.status == .started && $0.contains(userID: meID) }
    for g in candidates {
      let activeID = "ag_" + g.id
      if store.activeGames.contains(where: { $0.id == activeID }) { continue }

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

