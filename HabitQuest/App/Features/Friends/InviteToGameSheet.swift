import SwiftUI

struct InviteToGameSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore

  let friend: PublicUser
  @State private var title: String = "7-day Steps Battle"
  @State private var settings: GameSettings = .default(mode: .oneOnOne)

  var body: some View {
    NavigationStack {
      Form {
        Section("Invite") {
          HStack {
            Text("To")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text(friend.displayName)
              Text("@\(friend.handle)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
          TextField("Game title", text: $title)
        }

        GameSettingsForm(settings: $settings, availableModes: [.oneOnOne], inventory: store.profile?.inventory)

        Section {
          Button("Send invite") {
            GameInvitesService(store: store).invite(friend: friend, title: title, settings: settings)
            dismiss()
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .navigationTitle("New game")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

