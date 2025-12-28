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

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mostPointsAtEnd: "Most points at end"
    }
  }
}

/// Fully customizable later; for now provides the core knobs you asked for.
struct GameSettings: Codable, Equatable, Hashable {
  var mode: GameModeKind
  var activity: GameActivity
  /// Competition length in days.
  var timeLimitDays: Int
  var winCondition: GameWinCondition
  /// Placeholder for future structured rules. (e.g. “No treadmills”, “Rest day allowed”, etc.)
  var customRulesNote: String

  static func `default`(mode: GameModeKind) -> GameSettings {
    GameSettings(
      mode: mode,
      activity: .steps,
      timeLimitDays: 7,
      winCondition: .mostPointsAtEnd,
      customRulesNote: ""
    )
  }
}

