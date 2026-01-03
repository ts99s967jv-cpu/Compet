import SwiftUI

struct NotificationsView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Notifications")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          if store.notifications.isEmpty {
            Text("You’re all caught up.")
              .font(DS.Typography.body)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .padding(.horizontal, DS.Spacing.xl)
              .padding(.top, DS.Spacing.m)
          } else {
            VStack(spacing: DS.Spacing.m) {
              ForEach(store.notifications) { n in
                Button {
                  store.markNotificationRead(n.id)
                } label: {
                  HStack(alignment: .top, spacing: DS.Spacing.m) {
                    Circle()
                      .fill(n.isRead ? DS.Palette.separator(scheme) : DS.Palette.accent)
                      .frame(width: 10, height: 10)
                      .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 6) {
                      Text(n.kind.title)
                        .font(DS.Typography.section)
                        .foregroundStyle(DS.Palette.text(scheme))

                      Text(n.headline)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(DS.Palette.text(scheme))

                      Text(n.body)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Palette.subtext(scheme))

                      Text(n.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.subtext(scheme))
                        .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                  }
                  .padding(.horizontal, DS.Spacing.xl)
                  .padding(.vertical, DS.Spacing.m)
                  .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                      .fill(DS.Palette.surface(scheme))
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                      .stroke(DS.Palette.separator(scheme), lineWidth: 1)
                  )
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.horizontal, DS.Spacing.xl)
          }

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if !store.notifications.isEmpty {
            Menu {
              Button("Mark all as read") { store.markAllNotificationsRead() }
              Button("Clear all", role: .destructive) { store.clearAllNotifications() }
            } label: {
              Image(systemName: "ellipsis.circle")
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
          }
        }
      }
    }
  }
}

