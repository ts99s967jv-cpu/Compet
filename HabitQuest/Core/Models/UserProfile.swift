import Foundation

struct UserProfile: Codable, Equatable, Identifiable {
  var id: String

  var displayName: String
  /// Unique-ish username/handle used for search (local prototype).
  var handle: String

  var age: Int
  var gender: Gender
  var fitnessLevel: FitnessLevel
  var visibility: ProfileVisibility

  var createdAt: Date
  var updatedAt: Date

  func asPublicUser() -> PublicUser {
    PublicUser(
      id: id,
      displayName: displayName,
      handle: handle,
      visibility: visibility
    )
  }
}

