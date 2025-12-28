import Foundation

enum ClanBattleStatus: String, Codable, CaseIterable, Identifiable {
  case pending
  case active
  case finished

  var id: String { rawValue }
}

/// Team-vs-team battle between two clans.
/// Local prototype: stores summary info; scoring rules can later be extended (e.g. steps/week via HealthKit).
struct ClanBattle: Codable, Equatable, Identifiable, Hashable {
  var id: String

  var title: String
  var createdAt: Date
  var status: ClanBattleStatus
  var settings: GameSettings

  var clanAID: String
  var clanAName: String
  var clanATag: String

  var clanBID: String
  var clanBName: String
  var clanBTag: String

  /// Placeholder team scores (wire to HealthKit aggregation later).
  var clanAScore: Int
  var clanBScore: Int
}

