import SwiftUI

struct FriendsView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var searchQuery: String = ""
  @State private var searchResults: [PublicUser] = []
  @State private var inviteFriend: PublicUser?
  @State private var viewUser: PublicUser?
  @State private var isSearching: Bool = false

  private let directory = UserDirectoryService()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Friends")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          Text("Search people, view profiles, add friends, and invite them to games.")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .padding(.horizontal, DS.Spacing.xl)

          if !store.friendRequests.isEmpty {
            DSSectionHeaderRow(title: "Requests", systemImage: "person.crop.circle.badge.plus")
            VStack(spacing: DS.Spacing.s) {
              ForEach(store.friendRequests.filter { $0.status == .pending }) { req in
                FriendRequestRow(store: store, request: req)
                if req.id != store.friendRequests.filter({ $0.status == .pending }).last?.id {
                  Divider().overlay(DS.Palette.separator(scheme))
                }
              }
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)
          }

          if !searchResults.isEmpty {
            DSSectionHeaderRow(title: "Search results", systemImage: "magnifyingglass")
            VStack(spacing: DS.Spacing.s) {
              ForEach(searchResults) { user in
                FriendRow(
                  user: user,
                  isFriend: store.friends.contains(where: { $0.user.id == user.id }),
                  view: { viewUser = user },
                  add: {
                    if Backend.shared.isAvailable {
                      Task { await BackendFriendsService(store: store).sendRequest(to: user.id) }
                    } else {
                      FriendsService(store: store).addFriend(user)
                    }
                  },
                  invite: { inviteFriend = user }
                )
                if user.id != searchResults.last?.id {
                  Divider().overlay(DS.Palette.separator(scheme))
                }
              }
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)
          } else if isSearching {
            DSSectionHeaderRow(title: "Search results", systemImage: "magnifyingglass")
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("Searching…")
                .font(DS.Typography.section)
              Text("Looking up users.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)
          } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DSSectionHeaderRow(title: "Search results", systemImage: "magnifyingglass")
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("No results")
                .font(DS.Typography.section)
              Text("Try a different name or handle.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)
          }

          DSSectionHeaderRow(title: "Your friends", systemImage: "person.2")
          VStack(spacing: DS.Spacing.s) {
            if store.friends.isEmpty {
              VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("No friends yet")
                  .font(DS.Typography.section)
                Text("Search above to add someone.")
                  .font(DS.Typography.body)
                  .foregroundStyle(DS.Palette.subtext(scheme))
              }
            } else {
              ForEach(store.friends) { friend in
                FriendRow(
                  user: friend.user,
                  isFriend: true,
                  view: { viewUser = friend.user },
                  add: {},
                  invite: { inviteFriend = friend.user }
                )
                if friend.id != store.friends.last?.id {
                  Divider().overlay(DS.Palette.separator(scheme))
                }
              }
            }
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .searchable(text: $searchQuery, prompt: "Search by name or handle")
      .onChange(of: searchQuery) { _, newValue in
        Task {
          let q = newValue
          let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else {
            await MainActor.run { searchResults = [] }
            return
          }

          if Backend.shared.isAvailable {
            await MainActor.run { isSearching = true }
            do {
              let results = try await Backend.shared.searchUsers(query: trimmed)
              let meID = store.profile?.id
              await MainActor.run {
                searchResults = results.filter { $0.id != meID }
                isSearching = false
              }
            } catch {
              await MainActor.run {
                searchResults = []
                isSearching = false
              }
            }
          } else {
            await MainActor.run {
              searchResults = directory.search(query: trimmed, excluding: store.profile?.id)
            }
          }
        }
      }
      .refreshable {
        await BackendFriendsService(store: store).refresh()
      }
      .sheet(item: $inviteFriend) { friend in
        InviteToGameSheet(store: store, friend: friend)
      }
      .sheet(item: $viewUser) { user in
        PublicUserProfileSheet(store: store, user: user)
      }
    }
  }
}

private struct FriendRow: View {
  @Environment(\.colorScheme) private var scheme
  let user: PublicUser
  let isFriend: Bool
  let view: () -> Void
  let add: () -> Void
  let invite: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(DS.Palette.accent.opacity(0.14))
        .frame(width: 38, height: 38)
        .overlay(
          Image(systemName: "person.fill")
            .foregroundStyle(DS.Palette.accent)
            .font(.system(size: 14, weight: .semibold))
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(user.displayName)
          .font(DS.Typography.body.weight(.semibold))
        Text("@\(user.handle)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
      Spacer()
      Button {
        view()
      } label: {
        Image(systemName: "info.circle")
          .foregroundStyle(DS.Palette.subtext(scheme))
          .padding(.horizontal, 6)
          .padding(.vertical, 6)
      }
      .buttonStyle(.plain)

      if isFriend {
        Button("Invite") { invite() }
          .buttonStyle(.bordered)
      } else {
        HStack(spacing: 8) {
          Button("Invite") { invite() }
            .buttonStyle(.bordered)
          Button("Add") { add() }
            .buttonStyle(.borderedProminent)
        }
      }
    }
  }
}

private struct FriendRequestRow: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
  let request: FriendRequest

  private var meID: String? { store.profile?.id }
  private var isIncoming: Bool { request.to.id == meID }
  private var other: PublicUser { isIncoming ? request.from : request.to }

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(DS.Palette.accent.opacity(0.14))
        .frame(width: 38, height: 38)
        .overlay(
          Image(systemName: "person.fill")
            .foregroundStyle(DS.Palette.accent)
            .font(.system(size: 14, weight: .semibold))
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(other.displayName)
          .font(DS.Typography.body.weight(.semibold))
        Text(isIncoming ? "Incoming request" : "Request sent")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      Spacer()

      if isIncoming {
        Button("Decline", role: .destructive) {
          Task { await BackendFriendsService(store: store).decline(requestID: request.id) }
        }
        .buttonStyle(.bordered)

        Button("Accept") {
          Task { await BackendFriendsService(store: store).accept(requestID: request.id) }
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Palette.accent)
      } else {
        Text("Pending")
          .font(DS.Typography.caption.weight(.semibold))
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
    }
  }
}

