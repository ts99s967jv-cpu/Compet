import Foundation

struct AgeCohort: Equatable, Hashable, Codable {
  var label: String
  var minAge: Int
  var maxAgeInclusive: Int?

  func contains(age: Int) -> Bool {
    if age < minAge { return false }
    if let maxAgeInclusive, age > maxAgeInclusive { return false }
    return true
  }

  static func forAge(_ age: Int) -> AgeCohort {
    let a = max(13, min(100, age))
    for c in cohorts {
      if c.contains(age: a) { return c }
    }
    return AgeCohort(label: "All", minAge: 13, maxAgeInclusive: nil)
  }

  static let cohorts: [AgeCohort] = [
    AgeCohort(label: "13–17", minAge: 13, maxAgeInclusive: 17),
    AgeCohort(label: "18–24", minAge: 18, maxAgeInclusive: 24),
    AgeCohort(label: "25–34", minAge: 25, maxAgeInclusive: 34),
    AgeCohort(label: "35–44", minAge: 35, maxAgeInclusive: 44),
    AgeCohort(label: "45–54", minAge: 45, maxAgeInclusive: 54),
    AgeCohort(label: "55–64", minAge: 55, maxAgeInclusive: 64),
    AgeCohort(label: "65+", minAge: 65, maxAgeInclusive: nil),
  ]
}

