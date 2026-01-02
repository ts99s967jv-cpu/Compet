import Foundation

@MainActor
final class PublicGamesService {
  private let store: AppStore
  private let backend: BackendClient

  init(store: AppStore) {
    self.store = store
    self.backend = Backend.shared
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

    // Supabase-backed create (then refresh list).
    if backend.isAvailable {
      Task {
        do {
          try await backend.createPublicGame(game)
          let games = try await backend.listPublicGames()
          await MainActor.run {
            store.publicGames = games
            store.saveAll()
          }
        } catch {
          // If backend failed, remove the optimistic local insert so it doesn't "vanish later" on re-login.
          await MainActor.run {
            store.publicGames.removeAll { $0.id == game.id }
            store.saveAll()
          }
        }
      }
    }
  }

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

    if backend.isAvailable, game.visibility != .systemEvent {
      Task {
        do {
          try await backend.joinPublicGame(gameID: gameID)
          let games = try await backend.listPublicGames()
          await MainActor.run {
            store.publicGames = games
            store.saveAll()
          }
        } catch {}
      }
    }

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

    // If this lobby is an elimination-style game and it just started, spawn an ActiveGame.
    if game.status == .started {
      if isEliminationStyle(game.settings.winCondition) {
        ActiveGamesService(store: store).startEliminationStyleGame(from: game)
      } else if game.settings.winCondition == .levelVsLevelGoal {
        ActiveGamesService(store: store).startLevelVsLevelGame(from: game)
      }
    }
  }

  func leave(gameID: String) {
    guard let me = store.profile?.asPublicUser() else { return }
    guard var game = store.publicGames.first(where: { $0.id == gameID }) else { return }

    game.players.removeAll { $0.user.id == me.id }
    // Leaving should remove the lobby from your UI.
    store.hidePublicGame(gameID: game.id)

    if backend.isAvailable, game.visibility != .systemEvent {
      Task {
        do {
          try await backend.leavePublicGame(gameID: gameID)
          let games = try await backend.listPublicGames()
          await MainActor.run {
            store.publicGames = games.filter { !store.hiddenPublicGameIDs.contains($0.id) }
            store.saveAll()
          }
        } catch {
          // Keep it hidden locally; backend may have rejected the leave due to RLS.
          await MainActor.run {
            store.saveAll()
          }
        }
      }
    }

    // For system events, also remove from the active season game (prototype).
    if game.visibility == .systemEvent {
      ActiveGamesService(store: store).removePlayerFromActiveGame(activeGameID: "ag_" + game.id, userID: me.id)
    }
  }

  func close(gameID: String) {
    guard let meID = store.profile?.id else { return }
    guard let game = store.publicGames.first(where: { $0.id == gameID }) else { return }
    guard game.createdBy.id == meID else { return }
    store.hidePublicGame(gameID: gameID)
    if backend.isAvailable, game.visibility != .systemEvent {
      Task {
        try? await backend.closePublicGame(gameID: gameID)
        let games = (try? await backend.listPublicGames()) ?? []
        await MainActor.run {
          store.publicGames = games.filter { !store.hiddenPublicGameIDs.contains($0.id) }
          store.saveAll()
        }
      }
    }
  }

  func delete(gameID: String) {
    guard let meID = store.profile?.id else { return }
    guard let game = store.publicGames.first(where: { $0.id == gameID }) else { return }
    guard game.createdBy.id == meID else { return }
    store.hidePublicGame(gameID: gameID)
    if backend.isAvailable, game.visibility != .systemEvent {
      Task {
        try? await backend.deletePublicGame(gameID: gameID)
        let games = (try? await backend.listPublicGames()) ?? []
        await MainActor.run {
          store.publicGames = games.filter { !store.hiddenPublicGameIDs.contains($0.id) }
          store.saveAll()
        }
      }
    }
  }

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

    if backend.isAvailable, game.visibility != .systemEvent {
      Task {
        do {
          try await backend.startPublicGameNow(gameID: gameID)
          let games = try await backend.listPublicGames()
          await MainActor.run {
            store.publicGames = games
            store.saveAll()
          }
        } catch {}
      }
    }

    if isEliminationStyle(game.settings.winCondition) {
      ActiveGamesService(store: store).startEliminationStyleGame(from: game)
    } else if game.settings.winCondition == .levelVsLevelGoal {
      ActiveGamesService(store: store).startLevelVsLevelGame(from: game)
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

