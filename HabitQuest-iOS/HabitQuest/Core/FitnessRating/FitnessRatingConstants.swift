import Foundation

enum FitnessRatingConstants {
  static let confidenceMin: Double = 0.15
  static let sigmaExpectedFPS: Double = 400.0
  static let baseK: Double = 50.0

  static let metricWindowDays: Int = 42
  static let fullConfidenceTargetDays: Int = 42
  static let defaultCohortMeanElo: Double = 1500.0

  static let weights: [FitnessMetric: Double] = [
    .vo2Max: 0.22,
    .hrvSDNN: 0.18,
    .restingHeartRate: 0.16,
    .steps: 0.16,
    .sleepDuration: 0.14,
    .respiratoryRate: 0.07,
    .spO2: 0.07,
  ]
}

