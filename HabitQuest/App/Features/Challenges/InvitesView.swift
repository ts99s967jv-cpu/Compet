import SwiftUI

struct InvitesView: View {
  @Bindable var store: AppStore

  private var meID: String? { store.profile?.id }

  var body: some View {
    NavigationStack {
      List {
        if store.invites.isEmpty {
          Text("No invites yet. Invite a friend to start a game.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(store.invites) { invite in
            InviteRow(
              invite: invite,
              isIncoming: invite.to.id == meID,
              accept: { GameInvitesService(store: store).accept(inviteID: invite.id) },
              decline: { GameInvitesService(store: store).decline(inviteID: invite.id) }
            )
          }
        }
      }
      .navigationTitle("Games")
    }
  }
}

private struct InviteRow: View {
  let invite: GameInvite
  let isIncoming: Bool
  let accept: () -> Void
  let decline: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(invite.title)
          .font(.headline)
        Spacer()
        Text(invite.status.rawValue.capitalized)
          .font(.footnote)
          .foregroundStyle(invite.status == .pending ? .secondary : .primary)
      }

      HStack(spacing: 8) {
        Text("\(invite.settings.activity.title) • \(invite.settings.timeLimitDays)d • \(invite.settings.winCondition.title)")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Spacer()
        if !invite.settings.enabledPowerUps.isEmpty {
          Text("Power-ups: \(invite.settings.enabledPowerUps.count)")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      if isIncoming {
        Text("From \(invite.from.displayName) (@\(invite.from.handle))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        Text("To \(invite.to.displayName) (@\(invite.to.handle))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if invite.status == .pending && isIncoming {
        HStack {
          Button("Decline", role: .destructive) { decline() }
            .buttonStyle(.bordered)
          Spacer()
          Button("Accept") { accept() }
            .buttonStyle(.borderedProminent)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

