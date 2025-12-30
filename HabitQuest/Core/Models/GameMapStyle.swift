import Foundation

enum GameMapStyle: String, Codable, CaseIterable, Identifiable {
  /// Pick a recommended style based on `GameActivity`.
  case automatic
  /// Soft grassy background with a light trail.
  case grassyTrail
  /// A clean road with subtle markings.
  case road
  /// A pool lane style.
  case pool
  /// Neutral path for any sport.
  case generic

  var id: String { rawValue }

  var title: String {
    switch self {
    case .automatic: "Automatic"
    case .grassyTrail: "Grassy trail"
    case .road: "Road"
    case .pool: "Pool"
    case .generic: "Generic"
    }
  }

  func resolved(for activity: GameActivity) -> GameMapStyle {
    switch self {
    case .automatic:
      switch activity {
      case .steps: return .grassyTrail
      case .running: return .grassyTrail
      case .cycling: return .road
      case .swimming: return .pool
      case .strengthTraining, .yoga, .meditation: return .generic
      }
    default:
      return self
    }
  }
}

