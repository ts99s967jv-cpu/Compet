import Foundation

enum MeasurementSystem: String, Codable, CaseIterable, Identifiable {
  case metric
  case imperial

  var id: String { rawValue }

  var title: String {
    switch self {
    case .metric: "Metric"
    case .imperial: "Imperial"
    }
  }
}

