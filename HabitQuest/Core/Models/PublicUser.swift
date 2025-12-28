import Foundation

/// A "public directory" view of a user (what search results / friends list can display).
struct PublicUser: Codable, Equatable, Identifiable, Hashable {
  var id: String
  var displayName: String
  var handle: String
  var visibility: ProfileVisibility
}

