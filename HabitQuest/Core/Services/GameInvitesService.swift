import Foundation

@MainActor
final class GameInvitesService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func invite(friend: PublicUser, title: String) {
    guard let me = store.profile?.asPublicUser() else { return }

    let invite = GameInvite(
      id: UUID().uuidString,
      from: me,
      to: friend,
      title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Challenge" : title,
      createdAt: Date(),
      status: .pending
    )
    store.addInvite(invite)
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

