import Foundation

enum FriendRequestStatus: String, Codable, CaseIterable, Identifiable {
  case pending
  case accepted
  case declined

  var id: String { rawValue }
}

/// Server-backed friend request (prototype schema for Supabase).
struct FriendRequest: Codable, Equatable, Identifiable, Hashable {
  var id: String
  var from: PublicUser
  var to: PublicUser
  var createdAt: Date
  var status: FriendRequestStatus
}

