import Foundation

enum FitnessRatingConstants {
  // MARK: Spec constants
  static let confidenceMin: Double = 0.15
  static let sigmaExpectedFPS: Double = 400.0
  static let baseK: Double = 50.0 // spec: 40–60

  // Window used for metric availability confidence.
  // Spec provides formula but not window size; we centralize it here.
  static let metricWindowDays: Int = 42

  // Confidence ramp target: full in ~4–6 weeks.
  // We treat 42 days of "good data" as full.
  static let fullConfidenceTargetDays: Int = 42

  // Age cohort fallback mean when no live cohort distribution exists.
  static let defaultCohortMeanElo: Double = 1500.0

  // MARK: Weights (centralized + adjustable)
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

