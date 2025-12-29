import Foundation

/// Represents the signed-in user session.
struct Account: Codable, Equatable {
  /// Stable local identifier (prototype). Currently derived from email.
  var userID: String
  var email: String
  var username: String
  var createdAt: Date
}

extension Account {
  /// Backwards-compatible decoding from older Sign in with Apple model.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if let apple = try? c.decode(String.self, forKey: .appleUserID) {
      userID = apple
      email = ""
      username = ""
      createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
      return
    }

    userID = try c.decode(String.self, forKey: .userID)
    email = try c.decode(String.self, forKey: .email)
    username = try c.decode(String.self, forKey: .username)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
  }

  private enum CodingKeys: String, CodingKey {
    case userID, email, username, createdAt
    case appleUserID
  }
}

