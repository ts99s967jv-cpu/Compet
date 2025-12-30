import Foundation

/// Locally-stored (prototype) leaderboard score for a specific game round and user.
///
/// - Note: In a production app, this would be server-authored and shared between devices/users.
struct GameScore: Codable, Equatable, Identifiable, Hashable {
  /// Composite stable identifier.
  var id: String { "\(activeGameID)|\(roundIndex)|\(userID)" }

  /// The `ActiveGame.id` this score belongs to (e.g. `"ag_<publicGameID>"`).
  var activeGameID: String
  var roundIndex: Int
  var userID: String

  /// Points for the round window.
  var points: Int
  /// When this score was last computed on-device.
  var updatedAt: Date
}

