import Foundation

enum AppNotificationKind: String, Codable, CaseIterable, Identifiable, Hashable {
  case friendRequest
  case gameInvite
  case gameLeadChange
  case gameMilestone
  case system

  var id: String { rawValue }

  var title: String {
    switch self {
    case .friendRequest: "Friend request"
    case .gameInvite: "Game invite"
    case .gameLeadChange: "Lead change"
    case .gameMilestone: "Milestone"
    case .system: "Update"
    }
  }
}

struct AppNotification: Codable, Equatable, Identifiable, Hashable {
  var id: String
  var kind: AppNotificationKind
  var createdAt: Date
  var isRead: Bool

  /// Short user-visible title (may duplicate kind title).
  var headline: String
  /// Supporting body text.
  var body: String

  /// Optional linkage for deep-linking / filtering.
  var relatedUserID: String?
  var relatedGameID: String?
  var relatedActiveGameID: String?
  var relatedFriendRequestID: String?
  var relatedInviteID: String?

  init(
    id: String = UUID().uuidString,
    kind: AppNotificationKind,
    createdAt: Date = Date(),
    isRead: Bool = false,
    headline: String,
    body: String,
    relatedUserID: String? = nil,
    relatedGameID: String? = nil,
    relatedActiveGameID: String? = nil,
    relatedFriendRequestID: String? = nil,
    relatedInviteID: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.createdAt = createdAt
    self.isRead = isRead
    self.headline = headline
    self.body = body
    self.relatedUserID = relatedUserID
    self.relatedGameID = relatedGameID
    self.relatedActiveGameID = relatedActiveGameID
    self.relatedFriendRequestID = relatedFriendRequestID
    self.relatedInviteID = relatedInviteID
  }
}

