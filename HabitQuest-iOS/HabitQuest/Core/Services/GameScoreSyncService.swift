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
        // Points are raw units (1 step = 1 point, 1 kcal = 1 point).
        // Always include all HealthKit sources (Watch + iPhone), regardless of "phoneOnlyMetrics".
        sourceFilter: .any
      )
      let score = GameScore(
        activeGameID: game.id,
        roundIndex: roundIndex,
        userID: meID,
        points: Int(pts.rounded()),
        updatedAt: now
      )
      store.upsertGameScore(score)

      // In-app notifications: milestones + lead changes (best-effort).
      maybeNotifyMilestone(game: game, score: score)
      maybeNotifyLeadChange(game: game, roundIndex: roundIndex)
    } catch {
      // No HealthKit available/authorized → leave existing score (if any).
    }
  }

  private func maybeNotifyMilestone(game: ActiveGame, score: GameScore) {
    let interval = milestoneInterval(for: game.settings.scoringMetrics)
    guard interval > 0 else { return }
    guard score.points > 0 else { return }

    let key = "\(score.activeGameID)|\(score.roundIndex)"
    let last = store.lastMilestoneNotifiedPointsByKey[key] ?? 0
    let next = ((last / interval) + 1) * interval
    guard score.points >= next else { return }

    let reached = (score.points / interval) * interval
    store.lastMilestoneNotifiedPointsByKey[key] = reached
    store.saveAll()

    let headline = game.title
    let body = "You reached \(reached) points."
    store.addNotification(AppNotification(
      kind: .gameMilestone,
      headline: headline,
      body: body,
      relatedActiveGameID: score.activeGameID
    ))
    LocalNotificationService.shared.postIfAllowed(title: "Milestone", body: "\(game.title): \(reached) points")
  }

  private func milestoneInterval(for metrics: [ScoreMetric]) -> Int {
    // Steps-based games: 1k points increments feels right.
    if metrics.contains(.steps) { return 1_000 }
    if metrics.contains(.activeEnergyBurned) { return 200 }
    if metrics.contains(.sleepScore) { return 10 }
    return 1_000
  }

  private func maybeNotifyLeadChange(game: ActiveGame, roundIndex: Int) {
    let scores = store.gameScores.filter { $0.activeGameID == game.id && $0.roundIndex == roundIndex }
    let uniqueUsers = Set(scores.map { $0.userID })
    guard uniqueUsers.count >= 2 else { return }

    guard let top = scores.max(by: { $0.points < $1.points }) else { return }
    let newLeader = top.userID
    let oldLeader = store.lastLeaderUserIDByActiveGameID[game.id]
    guard oldLeader != newLeader else { return }

    store.lastLeaderUserIDByActiveGameID[game.id] = newLeader
    store.saveAll()

    let meID = store.profile?.id
    let leaderName = game.players.first(where: { $0.id == newLeader })?.displayName ?? "Someone"
    let headline = game.title
    let body: String
    if newLeader == meID {
      body = "You took the lead."
    } else if oldLeader == meID {
      body = "\(leaderName) took the lead."
    } else {
      body = "\(leaderName) is now in the lead."
    }

    store.addNotification(AppNotification(
      kind: .gameLeadChange,
      headline: headline,
      body: body,
      relatedUserID: newLeader,
      relatedActiveGameID: game.id
    ))
    LocalNotificationService.shared.postIfAllowed(title: "Lead change", body: "\(game.title): \(body)")
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

