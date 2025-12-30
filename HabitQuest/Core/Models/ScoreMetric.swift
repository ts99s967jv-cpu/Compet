import Foundation

/// Metrics used for scoring games (each player contributes their own HealthKit data).
enum ScoreMetric: String, Codable, CaseIterable, Identifiable, Hashable {
  case steps
  /// Active energy burned (kcal).
  case activeEnergyBurned
  /// Computed from sleep duration (0-100). Not an Apple-provided score.
  case sleepScore

  var id: String { rawValue }

  var title: String {
    switch self {
    case .steps: "Steps"
    case .activeEnergyBurned: "Calories burned"
    case .sleepScore: "Sleep score"
    }
  }

  var shortTitle: String {
    switch self {
    case .steps: "Steps"
    case .activeEnergyBurned: "Calories"
    case .sleepScore: "Sleep"
    }
  }
}

