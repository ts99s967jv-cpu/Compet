import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable {
  case female
  case male
  case nonBinary
  case preferNotToSay

  var id: String { rawValue }

  var title: String {
    switch self {
    case .female: "Female"
    case .male: "Male"
    case .nonBinary: "Non-binary"
    case .preferNotToSay: "Prefer not to say"
    }
  }
}

