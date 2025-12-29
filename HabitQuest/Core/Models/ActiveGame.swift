import Foundation

enum ActiveGameStatus: String, Codable, CaseIterable, Identifiable {
  case active
  case finished

  var id: String { rawValue }
}

struct EliminationState: Codable, Equatable, Hashable {
  /// The start time of the current 24h round.
  var roundStartedAt: Date
  /// Fixed at 24 hours for this mode (kept configurable for future).
  var roundLengthHours: Int
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

