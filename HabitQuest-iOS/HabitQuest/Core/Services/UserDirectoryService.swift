import Foundation

/// Local prototype "directory" used for search. Replace with a real backend later.
final class UserDirectoryService {
  private let users: [PublicUser]

  init(seedUsers: [PublicUser]? = nil) {
    self.users = seedUsers ?? [
      PublicUser(id: "u_alex", displayName: "Alex", handle: "alex", visibility: .public),
      PublicUser(id: "u_sam", displayName: "Sam", handle: "samfit", visibility: .public),
      PublicUser(id: "u_jordan", displayName: "Jordan", handle: "jordan", visibility: .public),
      PublicUser(id: "u_casey", displayName: "Casey", handle: "casey", visibility: .private),
      PublicUser(id: "u_taylor", displayName: "Taylor", handle: "taylor", visibility: .public),
    ]
  }

  func search(query: String, excluding userID: String?) -> [PublicUser] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }

    return users
      .filter { user in
        if let userID, user.id == userID { return false }
        return user.displayName.localizedCaseInsensitiveContains(q) || user.handle.localizedCaseInsensitiveContains(q)
      }
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }
}

