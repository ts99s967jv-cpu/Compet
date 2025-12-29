import Foundation

enum ProfileVisibility: String, Codable, CaseIterable, Identifiable {
  case `public`
  case `private`

  var id: String { rawValue }

  var title: String {
    switch self {
    case .public: "Public"
    case .private: "Private"
    }
  }
}

