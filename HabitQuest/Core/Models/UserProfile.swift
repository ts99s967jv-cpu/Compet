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

  /// Earned power-ups/debuffs (inventory).
  var inventory: UserInventory

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

extension UserProfile {
  /// Backwards-compatible decoding so older saved profiles can still load.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)

    id = try c.decode(String.self, forKey: .id)
    displayName = try c.decode(String.self, forKey: .displayName)
    handle = try c.decode(String.self, forKey: .handle)

    age = try c.decode(Int.self, forKey: .age)
    gender = try c.decode(Gender.self, forKey: .gender)
    fitnessLevel = try c.decode(FitnessLevel.self, forKey: .fitnessLevel)
    visibility = try c.decode(ProfileVisibility.self, forKey: .visibility)

    inventory = (try? c.decode(UserInventory.self, forKey: .inventory)) ?? .empty

    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }
}

