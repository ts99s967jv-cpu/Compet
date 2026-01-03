import SwiftUI

struct FriendsView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var searchQuery: String = ""
  @State private var searchResults: [PublicUser] = []
  @State private var inviteFriend: PublicUser?
  @State private var viewUser: PublicUser?
  @State private var isSearching: Bool = false
  @State private var statusMessage: String?
  @State private var searchTask: Task<Void, Never>?

  private let directory = UserDirectoryService()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Friends")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          Text("Search people, manage your friendships, and invite friends to games.")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .padding(.horizontal, DS.Spacing.xl)

          if let statusMessage {
            Text(statusMessage)
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .padding(.horizontal, DS.Spacing.xl)
          }

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
                    Task { await addFriendTapped(user: user) }
                  },
                  invite: { inviteFriend = user },
                  remove: nil
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
                Text("Use search above to find someone by name or @handle.")
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
                  invite: { inviteFriend = friend.user },
                  remove: { Task { await removeFriendTapped(userID: friend.user.id) } }
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
        searchTask?.cancel()
        searchTask = Task { await runSearch(query: newValue) }
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
      .presentationDragIndicator(.visible)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
    }
  }

  private func normalizedSearchQuery(_ s: String) -> String {
    var q = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.hasPrefix("@") { q.removeFirst() }
    return q
  }

  private func runSearch(query: String) async {
    let q = normalizedSearchQuery(query)
    guard !q.isEmpty else {
      await MainActor.run {
        searchResults = []
        isSearching = false
        statusMessage = nil
      }
      return
    }

    // Simple debounce
    try? await Task.sleep(nanoseconds: 250_000_000)
    if Task.isCancelled { return }

    if Backend.shared.isAvailable {
      await MainActor.run { isSearching = true; statusMessage = nil }
      do {
        let results = try await Backend.shared.searchUsers(query: q)
        let meID = store.profile?.id
        await MainActor.run {
          searchResults = results.filter { $0.id != meID }
          isSearching = false
          if searchResults.isEmpty {
            statusMessage = "No matches. If you searched by @handle, ensure the other user completed profile setup."
          }
        }
      } catch {
        await MainActor.run {
          searchResults = []
          isSearching = false
          statusMessage = "Search failed. This is usually a Supabase permissions (RLS) issue on the `profiles` table."
        }
      }
    } else {
      await MainActor.run {
        searchResults = directory.search(query: q, excluding: store.profile?.id)
        statusMessage = nil
      }
    }
  }

  private func addFriendTapped(user: PublicUser) async {
    statusMessage = nil
    if Backend.shared.isAvailable {
      do {
        try await Backend.shared.sendFriendRequest(to: user.id)
        await BackendFriendsService(store: store).refresh()
        await MainActor.run { statusMessage = "Friend request sent to @\(user.handle)." }
      } catch {
        await MainActor.run { statusMessage = "Couldn’t send friend request (Supabase permissions/RLS)."}
      }
    } else {
      FriendsService(store: store).addFriend(user)
      await MainActor.run { statusMessage = "Friend added (local)." }
    }
  }

  private func removeFriendTapped(userID: String) async {
    statusMessage = nil
    if Backend.shared.isAvailable {
      do {
        try await Backend.shared.removeFriend(userID: userID)
        await BackendFriendsService(store: store).refresh()
        await MainActor.run { statusMessage = "Friend removed." }
      } catch {
        await MainActor.run { statusMessage = "Couldn’t remove friend (Supabase permissions/RLS)." }
      }
    } else {
      FriendsService(store: store).removeFriend(userID: userID)
      await MainActor.run { statusMessage = "Friend removed (local)." }
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
  let remove: (() -> Void)?

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
        HStack(spacing: 8) {
          Button("Invite") { invite() }
            .buttonStyle(.bordered)
          if let remove {
            Button("Remove", role: .destructive) { remove() }
              .buttonStyle(.bordered)
          }
        }
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

