import SwiftUI

struct MainTabView: View {
  @Bindable var store: AppStore

  var body: some View {
#if os(iOS)
    TabView {
      TodayView(store: store)
        .tabItem { Label("Today", systemImage: "sun.max") }

      CompetitionsView(store: store)
        .tabItem { Label("Competitions", systemImage: "trophy") }

      NotificationsView(store: store)
        .tabItem { Label("Notifications", systemImage: "bell") }
        .badge(store.unreadNotificationsCount == 0 ? nil : Text("\(store.unreadNotificationsCount)"))

      ProfileView(store: store)
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }

      SettingsView(store: store)
        .tabItem { Label("Settings", systemImage: "gearshape") }
    }
    .tint(DS.Palette.accent)
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
#else
    TabView {
      TodayView(store: store)
        .tabItem { Label("Today", systemImage: "sun.max") }

      CompetitionsView(store: store)
        .tabItem { Label("Competitions", systemImage: "trophy") }

      ProfileView(store: store)
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
    }
    .tint(DS.Palette.accent)
#endif
  }
}

