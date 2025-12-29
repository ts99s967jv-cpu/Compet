import Foundation

enum TrackerOpponentPolicy: String, Codable, CaseIterable, Identifiable {
  case anyone
  case trackerOnly
  case noTrackerOnly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .anyone: "Anyone"
    case .trackerOnly: "Tracker users only"
    case .noTrackerOnly: "No-tracker users only"
    }
  }
}

