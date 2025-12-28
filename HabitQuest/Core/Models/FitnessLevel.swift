import Foundation

enum FitnessLevel: String, Codable, CaseIterable, Identifiable {
  case beginner
  case intermediate
  case advanced

  var id: String { rawValue }

  var title: String {
    switch self {
    case .beginner: "Beginner"
    case .intermediate: "Intermediate"
    case .advanced: "Advanced"
    }
  }
}

