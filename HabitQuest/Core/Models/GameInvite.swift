import Foundation

enum GameInviteStatus: String, Codable, CaseIterable, Identifiable {
  case pending
  case accepted
  case declined

  var id: String { rawValue }
}

/// A lightweight "game" invitation (local prototype; normally server-backed).
struct GameInvite: Codable, Equatable, Identifiable, Hashable {
  var id: String

  var from: PublicUser
  var to: PublicUser

  var title: String
  var createdAt: Date
  var status: GameInviteStatus
}

