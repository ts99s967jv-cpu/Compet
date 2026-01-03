import Foundation

@MainActor
final class PublicGamesService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func createPublicGame(title: String, settings: GameSettings, maxPlayers: Int, visibility: PublicGameVisibility) {
    guard let me = store.profile?.asPublicUser() else { return }
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

    let cap: Int
    switch settings.winCondition {
    case .eliminationLastManStanding:
      cap = 12
    case .levelVsLevelGoal:
      cap = 2
    case .kingOfMonth, .kingOfYear:
      cap = 100
    default:
      cap = 50
    }
    let clampedMax = min(cap, max(2, maxPlayers))
    let game = PublicGame(
      id: UUID().uuidString,
      title: trimmed.isEmpty ? "Public Challenge" : trimmed,
      createdAt: Date(),
      createdBy: me,
      visibility: visibility,
      isPinned: false,
      isUnlimitedPlayers: false,
      settings: settings,
      status: .open,
      maxPlayers: clampedMax,
      players: [PublicGamePlayer(user: me, joinedAt: Date())]
    )
    store.addPublicGame(game)
  }

  // No backend in this target; all actions are local-only.

  func join(gameID: String) {
    guard let profile = store.profile else { return }
    let me = profile.asPublicUser()
    guard var game = store.publicGames.first(where: { $0.id == gameID }) else { return }

    // System events can be joined even after "started" (prototype).
    if game.visibility == .systemEvent {
      guard game.status != .finished else { return }
    } else {
      guard game.status == .open, !game.isFull else { return }
    }
    if game.contains(userID: me.id) { return }
    guard isAllowedToJoin(game: game, profile: profile) else { return }

    game.players.append(PublicGamePlayer(user: me, joinedAt: Date()))
    if !game.isUnlimitedPlayers, game.players.count >= game.maxPlayers {
      game.status = .started
    }
    store.updatePublicGame(game)

    // System events must always have an active season game; add the player into it.
    if game.visibility == .systemEvent {
      SystemEventsService(store: store).sync()
      let activeID = "ag_" + game.id
      ActiveGamesService(store: store).addPlayerToActiveGame(activeGameID: activeID, user: me)
      // Immediately sync my score so the leaderboard updates as soon as I join.
      if let active = store.activeGames.first(where: { $0.id == activeID }) {
        Task { await GameScoreSyncService(store: store).syncMyScore(for: active) }
      }
    }

    // If this lobby just started, spawn an ActiveGame for supported modes.
    if game.status == .started {
      if isEliminationStyle(game.settings.winCondition) {
        ActiveGamesService(store: store).startEliminationStyleGame(from: game)
      } else if game.settings.winCondition == .levelVsLevelGoal {
        ActiveGamesService(store: store).startLevelVsLevelGame(from: game)
      } else if game.settings.winCondition == .mostPointsAtEnd {
        ActiveGamesService(store: store).startMostPointsGame(from: game)
      }
    }
  }

  func leave(gameID: String) {
    guard let me = store.profile?.asPublicUser() else { return }
    guard var game = store.publicGames.first(where: { $0.id == gameID }) else { return }

    game.players.removeAll { $0.user.id == me.id }
    if game.players.isEmpty {
      store.removePublicGame(gameID: game.id)
      return
    }
    if game.status == .started, game.players.count < game.maxPlayers {
      game.status = .open
    }
    store.updatePublicGame(game)

    // For system events, also remove from the active season game (prototype).
    if game.visibility == .systemEvent {
      ActiveGamesService(store: store).removePlayerFromActiveGame(activeGameID: "ag_" + game.id, userID: me.id)
    }

    // Leaving should remove the lobby from your UI.
    store.hidePublicGame(gameID: gameID)
  }

  func close(gameID: String) { store.hidePublicGame(gameID: gameID) }
  func delete(gameID: String) { store.hidePublicGame(gameID: gameID) }

  /// Allows the lobby owner to start early (useful if the lobby isn't filling).
  func startNow(gameID: String) {
    guard let profile = store.profile else { return }
    let me = profile.asPublicUser()
    guard var game = store.publicGames.first(where: { $0.id == gameID }) else { return }
    guard game.status == .open else { return }
    guard game.createdBy.id == me.id else { return }
    guard game.players.count >= 2 else { return }

    game.status = .started
    store.updatePublicGame(game)

    if isEliminationStyle(game.settings.winCondition) {
      ActiveGamesService(store: store).startEliminationStyleGame(from: game)
    } else if game.settings.winCondition == .levelVsLevelGoal {
      ActiveGamesService(store: store).startLevelVsLevelGame(from: game)
    } else if game.settings.winCondition == .mostPointsAtEnd {
      ActiveGamesService(store: store).startMostPointsGame(from: game)
    }
  }

  private func isAllowedToJoin(game: PublicGame, profile: UserProfile) -> Bool {
    // System events are open to everyone regardless of restrictions.
    if game.visibility == .systemEvent { return true }

    // Private lobbies require a friend relationship with the host (local prototype).
    if game.visibility == .private {
      if profile.id == game.createdBy.id { return true }
      return store.friends.contains(where: { $0.user.id == game.createdBy.id })
    }

    switch game.settings.opponentPolicy {
    case .anyone:
      return true
    case .trackerOnly:
      return profile.hasFitnessTracker
    case .noTrackerOnly:
      return !profile.hasFitnessTracker
    }
  }

  private func isEliminationStyle(_ win: GameWinCondition) -> Bool {
    win == .eliminationLastManStanding || win == .kingOfMonth || win == .kingOfYear
  }
}

