import Foundation

struct Friend: Codable, Equatable, Identifiable, Hashable {
  var id: String { user.id }
  var user: PublicUser
  var since: Date
}

