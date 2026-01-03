import Foundation

enum FitnessRatingMigration {
  static func v1ScoreToV2Elo(_ oldScore: Int) -> Double {
    let s = min(3000, max(0, oldScore))
    return 1000.0 + (Double(s) / 3000.0) * 1000.0
  }
}

