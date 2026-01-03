import Foundation

/// v2: Two-layer fitness rating.
///
/// - `elo`: externally visible competitive rating (no max cap)
/// - `fps`: internal 0...1 snapshot of current fitness performance
/// - `confidence`: internal 0.15...1 controlling Elo volatility (not shown to users)
struct FitnessRating: Equatable, Codable {
  var elo: Double
  var fps: Double
  var confidence: Double
}

extension FitnessRating {
  static func clampConfidence(_ value: Double) -> Double {
    min(1.0, max(FitnessRatingConstants.confidenceMin, value))
  }
}

