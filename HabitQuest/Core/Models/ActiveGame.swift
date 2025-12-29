import Foundation

enum ActiveGameStatus: String, Codable, CaseIterable, Identifiable {
  case active
  case finished

  var id: String { rawValue }
}

enum EliminationCadence: String, Codable, CaseIterable, Identifiable {
  case daily
  case weekly
  case monthly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .daily: "Daily"
    case .weekly: "Weekly"
    case .monthly: "Monthly"
    }
  }
}

struct EliminationState: Codable, Equatable, Hashable {
  /// The start time of the current round window.
  var roundStartedAt: Date
  /// Cadence for eliminations.
  var cadence: EliminationCadence
  /// Optional end date (e.g. end of month/year).
  var endsAt: Date?
  /// Incremented each time an elimination occurs.
  var roundIndex: Int

  /// Eliminated users in order (first eliminated first).
  var eliminatedUserIDs: [String]

  /// When finished:
  var winnerUserID: String?
}

/// A started game (as opposed to a lobby/invite). Local prototype.
struct ActiveGame: Codable, Equatable, Identifiable, Hashable {
  var id: String
  var title: String
  var createdAt: Date

  var settings: GameSettings
  var status: ActiveGameStatus

  var players: [PublicUser]

  /// Only present for elimination mode.
  var elimination: EliminationState?
}

