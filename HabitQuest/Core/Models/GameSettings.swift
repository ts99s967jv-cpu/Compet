import Foundation

enum GameModeKind: String, Codable, CaseIterable, Identifiable {
  /// 1v1 where you explicitly invite someone (friend or not).
  case oneOnOne
  /// You get matched against a random opponent (placeholder; backend required).
  case oneOnOneStranger
  /// Invite multiple friends; each receives an invite for the same group game.
  case groupFriends
  /// Clan vs clan team battle.
  case clanVsClan

  var id: String { rawValue }

  var title: String {
    switch self {
    case .oneOnOne: "1-on-1 (invite)"
    case .oneOnOneStranger: "1-on-1 (stranger)"
    case .groupFriends: "Group (friends)"
    case .clanVsClan: "Clan vs Clan"
    }
  }
}

enum GameActivity: String, Codable, CaseIterable, Identifiable {
  case steps
  case running
  case cycling
  case swimming
  case strengthTraining
  case yoga
  case meditation

  var id: String { rawValue }

  var title: String {
    switch self {
    case .steps: "Steps"
    case .running: "Running"
    case .cycling: "Cycling"
    case .swimming: "Swimming"
    case .strengthTraining: "Strength training"
    case .yoga: "Yoga"
    case .meditation: "Meditation"
    }
  }
}

enum GameWinCondition: String, Codable, CaseIterable, Identifiable {
  /// “Whoever reaches the most points by the end of the time.”
  case mostPointsAtEnd
  /// Level vs level goal: each day alternates player; must beat previous day's score, or lose.
  case levelVsLevelGoal
  /// Tier-based elimination: head-to-head eliminations until last player standing.
  case eliminationLastManStanding
  /// Elimination held weekly, ending at month end.
  case kingOfMonth
  /// Elimination held monthly, ending at year end.
  case kingOfYear

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mostPointsAtEnd: "Most points at end"
    case .levelVsLevelGoal: "Level vs level goal (daily beat-the-score)"
    case .eliminationLastManStanding: "Elimination (last man standing)"
    case .kingOfMonth: "King of the Month"
    case .kingOfYear: "King of the Year"
    }
  }
}

/// Fully customizable later; for now provides the core knobs you asked for.
struct GameSettings: Codable, Equatable, Hashable {
  var mode: GameModeKind
  var activity: GameActivity
  /// Metrics included in the points total (e.g. steps + calories burned).
  /// This is the "custom rule" used for scoring.
  var scoringMetrics: [ScoreMetric]
  /// Fairness setting: who is allowed to join (based on their profile tracker flag).
  var opponentPolicy: TrackerOpponentPolicy
  /// If enabled, restrict scoring metrics to phone-collected metrics (steps + calories).
  var phoneOnlyMetrics: Bool
  /// Competition length in days.
  var timeLimitDays: Int
  var winCondition: GameWinCondition
  /// Used only for `.levelVsLevelGoal` as the first day's target.
  var levelVsLevelStartingTarget: Int
  /// Power-ups/debuffs allowed for this match (match creator toggles these).
  var enabledPowerUps: [PowerUpID]
  /// Placeholder for future structured rules. (e.g. “No treadmills”, “Rest day allowed”, etc.)
  var customRulesNote: String

  static func `default`(mode: GameModeKind) -> GameSettings {
    GameSettings(
      mode: mode,
      activity: .steps,
      scoringMetrics: [.steps],
      opponentPolicy: .anyone,
      phoneOnlyMetrics: false,
      timeLimitDays: 7,
      winCondition: .mostPointsAtEnd,
      levelVsLevelStartingTarget: 10_000,
      enabledPowerUps: [],
      customRulesNote: ""
    )
  }
}

extension GameSettings {
  var scoringSummary: String {
    if scoringMetrics.isEmpty { return "Points" }
    let base = scoringMetrics.map(\.shortTitle).joined(separator: " + ")
    return phoneOnlyMetrics ? "\(base) (phone-only)" : base
  }
}

