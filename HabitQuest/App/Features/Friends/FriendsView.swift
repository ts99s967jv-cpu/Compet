import SwiftUI

struct FriendsView: View {
  @Bindable var store: AppStore

  @State private var searchQuery: String = ""
  @State private var searchResults: [PublicUser] = []
  @State private var inviteFriend: PublicUser?

  private let directory = UserDirectoryService()

  var body: some View {
    NavigationStack {
      List {
        if !searchResults.isEmpty {
          Section("Search results") {
            ForEach(searchResults) { user in
              SearchResultRow(
                user: user,
                isFriend: store.friends.contains(where: { $0.user.id == user.id }),
                addFriend: { FriendsService(store: store).addFriend(user) },
                invite: { inviteFriend = user }
              )
            }
          }
        }

        Section("Friends") {
          if store.friends.isEmpty {
            Text("No friends yet. Search above to add someone.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(store.friends) { friend in
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(friend.user.displayName)
                    .font(.headline)
                  Text("@\(friend.user.handle)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Invite") { inviteFriend = friend.user }
                  .buttonStyle(.bordered)
              }
              .contextMenu {
                Button(role: .destructive) {
                  FriendsService(store: store).removeFriend(userID: friend.user.id)
                } label: {
                  Label("Remove friend", systemImage: "person.fill.xmark")
                }
              }
            }
          }
        }
      }
      .navigationTitle("Friends")
      .searchable(text: $searchQuery, prompt: "Search by name or handle")
      .onChange(of: searchQuery) { _, newValue in
        searchResults = directory.search(query: newValue, excluding: store.profile?.id)
      }
      .sheet(item: $inviteFriend) { friend in
        InviteToGameSheet(store: store, friend: friend)
      }
    }
  }
}

private struct SearchResultRow: View {
  let user: PublicUser
  let isFriend: Bool
  let addFriend: () -> Void
  let invite: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(user.displayName)
          .font(.headline)
        Text("@\(user.handle)")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if isFriend {
        Button("Invite") { invite() }
          .buttonStyle(.bordered)
      } else {
        Button("Add") { addFriend() }
          .buttonStyle(.borderedProminent)
      }
    }
  }
}

