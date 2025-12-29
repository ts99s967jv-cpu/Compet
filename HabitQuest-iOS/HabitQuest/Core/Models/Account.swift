import Foundation

/// Represents the signed-in user session.
struct Account: Codable, Equatable {
  /// Stable identifier for Sign in with Apple (ASAuthorizationAppleIDCredential.user).
  var appleUserID: String
  var createdAt: Date
}

