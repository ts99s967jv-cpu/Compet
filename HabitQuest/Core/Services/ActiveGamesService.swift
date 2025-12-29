import Foundation

@MainActor
final class ActiveGamesService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  /// Starts an elimination game from a public lobby once it reaches capacity.
  func startEliminationGame(from publicGame: PublicGame, now: Date = Date()) {
    guard publicGame.settings.winCondition == .eliminationLastManStanding else { return }
    guard publicGame.players.count >= min(publicGame.maxPlayers, 12) else { return }

    let players = publicGame.players.map { $0.user }
    let game = ActiveGame(
      id: "ag_" + publicGame.id,
      title: publicGame.title,
      createdAt: now,
      settings: publicGame.settings,
      status: .active,
      players: players,
      elimination: EliminationState(
        roundStartedAt: now,
        roundLengthHours: 24,
        roundIndex: 0,
        eliminatedUserIDs: [],
        winnerUserID: nil
      )
    )
    store.addActiveGame(game)
  }

  /// Advances elimination games that have passed the 24h cutoff.
  /// Local prototype: the eliminated player is chosen by lowest deterministic "round points".
  func tick(now: Date = Date()) {
    for game in store.activeGames {
      guard game.status == .active else { continue }
      guard var elim = game.elimination else { continue }
      guard game.settings.winCondition == .eliminationLastManStanding else { continue }

      guard let cutoff = Calendar.current.date(byAdding: .hour, value: elim.roundLengthHours, to: elim.roundStartedAt) else { continue }
      guard now >= cutoff else { continue }

      var updated = game

      let remaining = updated.players.filter { !elim.eliminatedUserIDs.contains($0.id) }
      guard remaining.count > 1 else {
        updated.status = .finished
        updated.elimination?.winnerUserID = remaining.first?.id
        store.updateActiveGame(updated)
        continue
      }

      // Determine lowest points (placeholder until backend/HealthKit aggregation per user).
      let ranked = remaining
        .map { user in (user, pointsFor(userID: user.id, roundIndex: elim.roundIndex, seed: elim.roundStartedAt)) }
        .sorted { lhs, rhs in
          if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
          return lhs.0.id < rhs.0.id
        }

      let eliminated = ranked.first!.0
      elim.eliminatedUserIDs.append(eliminated.id)
      elim.roundIndex += 1
      elim.roundStartedAt = cutoff

      let remainingAfter = updated.players.filter { !elim.eliminatedUserIDs.contains($0.id) }
      if remainingAfter.count == 1 {
        updated.status = .finished
        elim.winnerUserID = remainingAfter.first?.id
      }

      updated.elimination = elim
      store.updateActiveGame(updated)
    }
  }

  func simulateEndOfRound(gameID: String) {
    // For UI testing: forces a tick by moving time forward.
    guard let game = store.activeGames.first(where: { $0.id == gameID }), let elim = game.elimination else { return }
    let now = Calendar.current.date(byAdding: .hour, value: elim.roundLengthHours, to: elim.roundStartedAt) ?? Date()
    tick(now: now)
  }

  func pointsFor(userID: String, roundIndex: Int, seed: Date) -> Int {
    // Deterministic pseudo-score for a round. Replace with real scoring later.
    let s = "\(userID)|\(roundIndex)|\(seed.timeIntervalSince1970)"
    var h: UInt64 = 1469598103934665603
    for b in s.utf8 {
      h ^= UInt64(b)
      h &*= 1099511628211
    }
    return Int(h % 10_000)
  }
}

