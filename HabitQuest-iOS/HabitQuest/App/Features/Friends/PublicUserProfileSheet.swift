import SwiftUI

struct PublicUserProfileSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore

  let user: PublicUser

  @State private var inviteToGame: Bool = false

  private var isFriend: Bool {
    store.friends.contains(where: { $0.user.id == user.id })
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          header
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Profile")
              .font(DS.Typography.section)

            HStack {
              Text("Visibility")
                .font(DS.Typography.body)
              Spacer()
              Text(user.visibility == .public ? "Public" : "Private")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(DS.Palette.subtext(scheme))
            }

            Text(user.visibility == .public ? "This user’s profile is public." : "This user’s profile is private.")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Actions")
              .font(DS.Typography.section)

            Button {
              inviteToGame = true
            } label: {
              HStack {
                Image(systemName: "paperplane")
                  .foregroundStyle(DS.Palette.accent)
                Text("Invite to a game")
                  .font(DS.Typography.body.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(DS.Palette.subtext(scheme))
              }
            }
            .buttonStyle(.plain)

            Divider().overlay(DS.Palette.separator(scheme))

            if isFriend {
              Button(role: .destructive) {
                FriendsService(store: store).removeFriend(userID: user.id)
              } label: {
                HStack {
                  Image(systemName: "person.fill.xmark")
                    .foregroundStyle(DS.Palette.danger)
                  Text("Remove friend")
                    .font(DS.Typography.body.weight(.semibold))
                  Spacer()
                }
              }
              .buttonStyle(.plain)
            } else {
              Button {
                FriendsService(store: store).addFriend(user)
              } label: {
                HStack {
                  Image(systemName: "person.fill.badge.plus")
                    .foregroundStyle(DS.Palette.accent)
                  Text("Add friend")
                    .font(DS.Typography.body.weight(.semibold))
                  Spacer()
                }
              }
              .buttonStyle(.plain)
            }
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
    }
    .sheet(isPresented: $inviteToGame) {
      InviteToGameSheet(store: store, friend: user)
    }
  }

  private var header: some View {
    HStack(spacing: DS.Spacing.m) {
      Circle()
        .fill(DS.Palette.accent.opacity(0.18))
        .frame(width: 56, height: 56)
        .overlay(
          Image(systemName: "person.fill")
            .foregroundStyle(DS.Palette.accent)
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(user.displayName)
          .font(DS.Typography.title)
        Text("@\(user.handle)")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      Spacer()

      if isFriend {
        Text("Friend")
          .font(DS.Typography.caption.weight(.semibold))
          .foregroundStyle(DS.Palette.accent)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Capsule(style: .continuous).fill(DS.Palette.accent.opacity(0.14)))
      }
    }
  }
}

