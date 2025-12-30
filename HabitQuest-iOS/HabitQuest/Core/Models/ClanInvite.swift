import Foundation

enum ClanInviteStatus: String, Codable, CaseIterable, Identifiable {
  case pending
  case accepted
  case declined

  var id: String { rawValue }
}

struct ClanInvite: Codable, Equatable, Identifiable, Hashable {
  var id: String

  var clanID: String
  var clanName: String
  var clanTag: String

  var from: PublicUser
  var to: PublicUser

  var createdAt: Date
  var status: ClanInviteStatus
}

