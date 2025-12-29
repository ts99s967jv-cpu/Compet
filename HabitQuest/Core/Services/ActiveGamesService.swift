import Foundation

@MainActor
final class ActiveGamesService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  /// Starts an elimination-style game (daily/weekly/monthly eliminations).
  func startEliminationStyleGame(from publicGame: PublicGame, now: Date = Date()) {
    guard isEliminationStyle(publicGame.settings.winCondition) else { return }
    guard publicGame.players.count >= 2 else { return }

    let players = publicGame.players.map { $0.user }
    let cadence = cadenceFor(publicGame.settings.winCondition)
    let endsAt = endsAtFor(publicGame.settings.winCondition, now: now)

    let game = ActiveGame(
      id: "ag_" + publicGame.id,
      title: publicGame.title,
      createdAt: now,
      settings: publicGame.settings,
      status: .active,
      players: players,
      elimination: EliminationState(
        roundStartedAt: now,
        cadence: cadence,
        endsAt: endsAt,
        roundIndex: 0,
        eliminatedUserIDs: [],
        winnerUserID: nil
      )
    )
    store.addActiveGame(game)
  }

  /// Advances elimination-style games that have passed the cadence cutoff.
  /// Local prototype: the eliminated player is chosen by lowest deterministic "round points".
  func tick(now: Date = Date()) {
    for game in store.activeGames {
      guard game.status == .active else { continue }
      guard var elim = game.elimination else { continue }
      guard isEliminationStyle(game.settings.winCondition) else { continue }

      var updated = game
      var safety = 0

      while safety < 24 {
        safety += 1
        guard let cutoff = nextCutoff(from: elim.roundStartedAt, cadence: elim.cadence) else { break }
        guard now >= cutoff else { break }

        let remaining = updated.players.filter { !elim.eliminatedUserIDs.contains($0.id) }
        if remaining.count <= 1 {
          // System-season games (month/year) shouldn't auto-finish just because nobody joined yet.
          if let endsAt = elim.endsAt, now < endsAt {
            break
          }
          updated.status = .finished
          elim.winnerUserID = remaining.first?.id
          updated.elimination = elim
          store.updateActiveGame(updated)
          break
        }

        // If this game has a fixed end date and we've reached/passed it, finish by eliminating down to 1.
        if let endsAt = elim.endsAt, cutoff >= endsAt {
          let rankedAsc = rankAscending(users: remaining, roundIndex: elim.roundIndex, seed: elim.roundStartedAt)
          for loser in rankedAsc.dropLast(1) {
            elim.eliminatedUserIDs.append(loser.id)
          }
          elim.winnerUserID = rankedAsc.last?.id
          updated.status = .finished
          elim.roundIndex += 1
          elim.roundStartedAt = cutoff
          updated.elimination = elim
          store.updateActiveGame(updated)
          break
        }

        let eliminationsThisRound = eliminationCountThisRound(
          remainingCount: remaining.count,
          afterCutoff: cutoff,
          cadence: elim.cadence,
          endsAt: elim.endsAt
        )

        let rankedAsc = rankAscending(users: remaining, roundIndex: elim.roundIndex, seed: elim.roundStartedAt)
        let toEliminate = rankedAsc.prefix(min(eliminationsThisRound, max(0, remaining.count - 1)))
        for loser in toEliminate {
          elim.eliminatedUserIDs.append(loser.id)
        }

        elim.roundIndex += 1
        elim.roundStartedAt = cutoff

        let remainingAfter = updated.players.filter { !elim.eliminatedUserIDs.contains($0.id) }
        if remainingAfter.count == 1 {
          updated.status = .finished
          elim.winnerUserID = remainingAfter.first?.id
          updated.elimination = elim
          store.updateActiveGame(updated)
          break
        }

        updated.elimination = elim
        store.updateActiveGame(updated)
      }
    }
  }

  func simulateEndOfRound(gameID: String) {
    // For UI testing: forces a tick by moving time forward.
    guard let game = store.activeGames.first(where: { $0.id == gameID }), let elim = game.elimination else { return }
    let now = nextCutoff(from: elim.roundStartedAt, cadence: elim.cadence) ?? Date()
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

  // MARK: - Helpers

  private func isEliminationStyle(_ win: GameWinCondition) -> Bool {
    win == .eliminationLastManStanding || win == .kingOfMonth || win == .kingOfYear
  }

  private func cadenceFor(_ win: GameWinCondition) -> EliminationCadence {
    switch win {
    case .eliminationLastManStanding:
      return .daily
    case .kingOfMonth:
      return .weekly
    case .kingOfYear:
      return .monthly
    default:
      return .daily
    }
  }

  private func endsAtFor(_ win: GameWinCondition, now: Date) -> Date? {
    let cal = Calendar.current
    switch win {
    case .kingOfMonth:
      let monthStart = cal.dateInterval(of: .month, for: now)?.start ?? now
      let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart)
      return nextMonth?.addingTimeInterval(-1)
    case .kingOfYear:
      let yearStart = cal.dateInterval(of: .year, for: now)?.start ?? now
      let nextYear = cal.date(byAdding: .year, value: 1, to: yearStart)
      return nextYear?.addingTimeInterval(-1)
    default:
      return nil
    }
  }

  private func nextCutoff(from start: Date, cadence: EliminationCadence) -> Date? {
    let cal = Calendar.current
    switch cadence {
    case .daily:
      return cal.date(byAdding: .day, value: 1, to: start)
    case .weekly:
      return cal.date(byAdding: .day, value: 7, to: start)
    case .monthly:
      return cal.date(byAdding: .month, value: 1, to: start)
    }
  }

  private func rankAscending(users: [PublicUser], roundIndex: Int, seed: Date) -> [PublicUser] {
    users
      .map { user in (user, pointsFor(userID: user.id, roundIndex: roundIndex, seed: seed)) }
      .sorted { lhs, rhs in
        if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
        return lhs.0.id < rhs.0.id
      }
      .map(\.0)
  }

  private func eliminationCountThisRound(remainingCount: Int, afterCutoff: Date, cadence: EliminationCadence, endsAt: Date?) -> Int {
    guard remainingCount > 1 else { return 0 }
    guard let endsAt else { return 1 }

    // Count remaining elimination opportunities after this cutoff and until endsAt.
    var opportunitiesAfterThis = 0
    var cursor = afterCutoff
    while let next = nextCutoff(from: cursor, cadence: cadence), next <= endsAt, opportunitiesAfterThis < 60 {
      opportunitiesAfterThis += 1
      cursor = next
    }

    let eventsLeftIncludingThis = max(1, opportunitiesAfterThis + 1)
    let needEliminations = remainingCount - 1
    return max(1, Int(ceil(Double(needEliminations) / Double(eventsLeftIncludingThis))))
  }

  // MARK: - System events / late join helpers

  func upsertSystemSeasonGame(publicGame: PublicGame, seasonStart: Date, seasonEnd: Date, now: Date = Date()) {
    let activeID = "ag_" + publicGame.id

    let cadence = cadenceFor(publicGame.settings.winCondition)
    let (roundStart, roundIndex) = currentRound(seasonStart: seasonStart, cadence: cadence, now: now)

    if var existing = store.activeGames.first(where: { $0.id == activeID }) {
      if existing.status == .finished { return }
      existing.settings = publicGame.settings
      existing.title = publicGame.title
      existing.players = unionPlayers(existing.players, publicGame.players.map(\.user))
      if var elim = existing.elimination {
        elim.cadence = cadence
        elim.endsAt = seasonEnd
        // Do NOT rewind roundStartedAt; keep whichever is later.
        if roundStart > elim.roundStartedAt {
          elim.roundStartedAt = roundStart
          elim.roundIndex = max(elim.roundIndex, roundIndex)
        }
        existing.elimination = elim
      } else {
        existing.elimination = EliminationState(
          roundStartedAt: roundStart,
          cadence: cadence,
          endsAt: seasonEnd,
          roundIndex: roundIndex,
          eliminatedUserIDs: [],
          winnerUserID: nil
        )
      }
      store.updateActiveGame(existing)
      return
    }

    let game = ActiveGame(
      id: activeID,
      title: publicGame.title,
      createdAt: seasonStart,
      settings: publicGame.settings,
      status: .active,
      players: publicGame.players.map(\.user),
      elimination: EliminationState(
        roundStartedAt: roundStart,
        cadence: cadence,
        endsAt: seasonEnd,
        roundIndex: roundIndex,
        eliminatedUserIDs: [],
        winnerUserID: nil
      )
    )
    store.addActiveGame(game)
  }

  func addPlayerToActiveGame(activeGameID: String, user: PublicUser) {
    guard var game = store.activeGames.first(where: { $0.id == activeGameID }) else { return }
    guard game.status == .active else { return }
    if game.players.contains(where: { $0.id == user.id }) { return }
    game.players.append(user)
    store.updateActiveGame(game)
  }

  func removePlayerFromActiveGame(activeGameID: String, userID: String) {
    guard var game = store.activeGames.first(where: { $0.id == activeGameID }) else { return }
    game.players.removeAll { $0.id == userID }
    store.updateActiveGame(game)
  }

  private func currentRound(seasonStart: Date, cadence: EliminationCadence, now: Date) -> (Date, Int) {
    let cal = Calendar.current
    switch cadence {
    case .daily:
      let days = cal.dateComponents([.day], from: seasonStart, to: now).day ?? 0
      let idx = max(0, days)
      let start = cal.date(byAdding: .day, value: idx, to: seasonStart) ?? seasonStart
      return (start, idx)
    case .weekly:
      let days = cal.dateComponents([.day], from: seasonStart, to: now).day ?? 0
      let idx = max(0, days / 7)
      let start = cal.date(byAdding: .day, value: idx * 7, to: seasonStart) ?? seasonStart
      return (start, idx)
    case .monthly:
      let from = cal.dateComponents([.year, .month], from: seasonStart)
      let to = cal.dateComponents([.year, .month], from: now)
      let months = (to.year ?? 0 - (from.year ?? 0)) * 12 + ((to.month ?? 0) - (from.month ?? 0))
      let idx = max(0, months)
      let start = cal.date(byAdding: .month, value: idx, to: seasonStart) ?? seasonStart
      return (start, idx)
    }
  }

  private func unionPlayers(_ a: [PublicUser], _ b: [PublicUser]) -> [PublicUser] {
    var seen: Set<String> = []
    var out: [PublicUser] = []
    for u in a + b {
      if seen.insert(u.id).inserted {
        out.append(u)
      }
    }
    return out
  }
}

