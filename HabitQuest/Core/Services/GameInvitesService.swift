import Foundation

@MainActor
final class GameInvitesService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func invite(friend: PublicUser, title: String, settings: GameSettings = .default(mode: .oneOnOne)) {
    guard let me = store.profile?.asPublicUser() else { return }

    let invite = GameInvite(
      id: UUID().uuidString,
      from: me,
      to: friend,
      title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Challenge" : title,
      settings: settings,
      groupID: nil,
      createdAt: Date(),
      status: .pending
    )
    store.addInvite(invite)
  }

  /// Local prototype: creates one invite per user, grouped by `groupID`.
  func inviteGroup(friends: [PublicUser], title: String, settings: GameSettings = .default(mode: .groupFriends)) {
    guard let me = store.profile?.asPublicUser() else { return }
    let groupID = UUID().uuidString

    for friend in friends {
      let invite = GameInvite(
        id: UUID().uuidString,
        from: me,
        to: friend,
        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Group Challenge" : title,
        settings: settings,
        groupID: groupID,
        createdAt: Date(),
        status: .pending
      )
      store.addInvite(invite)
    }
  }

  func accept(inviteID: String) {
    guard var invite = store.invites.first(where: { $0.id == inviteID }) else { return }
    invite.status = .accepted
    store.updateInvite(invite)
  }

  func decline(inviteID: String) {
    guard var invite = store.invites.first(where: { $0.id == inviteID }) else { return }
    invite.status = .declined
    store.updateInvite(invite)
  }
}

