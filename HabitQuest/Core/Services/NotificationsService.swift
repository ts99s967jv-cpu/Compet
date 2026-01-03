import Foundation

@MainActor
final class NotificationsService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func notifyNewFriendRequests(previousIDs: Set<String>, now: Date = Date()) {
    let current = store.friendRequests
    let newOnes = current.filter { !previousIDs.contains($0.id) && $0.status == .pending }
    guard !newOnes.isEmpty else { return }

    for req in newOnes {
      let headline = "\(req.from.displayName)"
      let body = "sent you a friend request."
      store.addNotification(AppNotification(
        kind: .friendRequest,
        createdAt: now,
        headline: headline,
        body: body,
        relatedUserID: req.from.id,
        relatedFriendRequestID: req.id
      ))
    }
  }

  func notifyNewInvites(previousIDs: Set<String>, now: Date = Date()) {
    let current = store.invites
    let newOnes = current.filter { !previousIDs.contains($0.id) && $0.status == .pending }
    guard !newOnes.isEmpty else { return }

    for inv in newOnes {
      store.addNotification(AppNotification(
        kind: .gameInvite,
        createdAt: now,
        headline: inv.title,
        body: "\(inv.from.displayName) invited you to a game.",
        relatedUserID: inv.from.id,
        relatedInviteID: inv.id
      ))
    }
  }
}

