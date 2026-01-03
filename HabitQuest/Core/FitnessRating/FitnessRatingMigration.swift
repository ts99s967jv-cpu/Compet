import Foundation

enum FitnessRatingMigration {
  /// v1 (0–3000) -> v2 Elo mapping required by spec:
  /// elo = 1000 + (oldScore / 3000) * 1000
  static func v1ScoreToV2Elo(_ oldScore: Int) -> Double {
    let s = min(3000, max(0, oldScore))
    return 1000.0 + (Double(s) / 3000.0) * 1000.0
  }
}

