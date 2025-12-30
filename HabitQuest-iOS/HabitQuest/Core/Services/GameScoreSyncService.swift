import Foundation

/// Computes and stores leaderboard scores on-device (prototype).
///
/// - Important: Only the current user's HealthKit data is available on device.
///   We still persist the computed score so it can be displayed consistently across the UI.
@MainActor
final class GameScoreSyncService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  /// Sync all active games the current user is participating in.
  func syncMyActiveGamesOnce(now: Date = Date()) async {
    guard let meID = store.profile?.id else { return }

    let myGames = store.activeGames.filter { g in
      g.status == .active && g.players.contains(where: { $0.id == meID })
    }
    guard !myGames.isEmpty else { return }

    for game in myGames {
      await syncMyScore(for: game, now: now)
    }
  }

  /// Sync the current user's score for a specific active game.
  func syncMyScore(for game: ActiveGame, now: Date = Date()) async {
    guard let meID = store.profile?.id else { return }
    guard game.players.contains(where: { $0.id == meID }) else { return }

    let (roundIndex, start) = roundWindow(for: game, now: now)
    let end = now

    let hk = HealthKitScoringService()
    do {
      try await hk.requestAuthorization(for: game.settings.scoringMetrics)
      let pts = try await hk.points(
        metrics: game.settings.scoringMetrics,
        start: start,
        end: end,
        sourceFilter: game.settings.phoneOnlyMetrics ? .iPhoneOnly : .any
      )
      let score = GameScore(
        activeGameID: game.id,
        roundIndex: roundIndex,
        userID: meID,
        points: Int(pts.rounded()),
        updatedAt: now
      )
      store.upsertGameScore(score)
    } catch {
      // No HealthKit available/authorized → leave existing score (if any).
    }
  }

  private func roundWindow(for game: ActiveGame, now: Date) -> (roundIndex: Int, start: Date) {
    if let elim = game.elimination {
      return (elim.roundIndex, elim.roundStartedAt)
    }
    if let lvl = game.levelVsLevel {
      return (lvl.turnIndex, lvl.turnStartedAt)
    }
    return (0, game.createdAt)
  }
}

