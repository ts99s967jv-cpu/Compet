import Foundation

enum ClanRole: String, Codable, CaseIterable, Identifiable {
  case owner
  case admin
  case member

  var id: String { rawValue }
}

struct ClanMember: Codable, Equatable, Hashable, Identifiable {
  var id: String { user.id }
  var user: PublicUser
  var role: ClanRole
  var joinedAt: Date
}

struct Clan: Codable, Equatable, Identifiable, Hashable {
  var id: String

  var name: String
  var tag: String
  var createdAt: Date
  var createdByUserID: String

  /// The clan roster (local prototype; in real app, this comes from backend).
  var members: [ClanMember]

  func isMember(userID: String) -> Bool {
    members.contains(where: { $0.user.id == userID })
  }
}

