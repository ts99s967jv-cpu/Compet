import Foundation

enum FitnessMetric: String, CaseIterable, Codable, Hashable {
  case steps
  case sleepDuration
  case restingHeartRate
  case hrvSDNN
  case vo2Max
  case spO2
  case respiratoryRate

  var title: String {
    switch self {
    case .steps: "Steps"
    case .sleepDuration: "Sleep"
    case .restingHeartRate: "Resting HR"
    case .hrvSDNN: "HRV (SDNN)"
    case .vo2Max: "VO₂ max"
    case .spO2: "SpO₂"
    case .respiratoryRate: "Respiratory rate"
    }
  }
}

