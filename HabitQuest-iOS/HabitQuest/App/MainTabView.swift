import SwiftUI

struct MainTabView: View {
  @Bindable var store: AppStore

  var body: some View {
#if os(iOS)
    TabView {
      TodayView(store: store)
        .tabItem { Label("Today", systemImage: "sun.max") }

      HabitsView(store: store)
        .tabItem { Label("Habits", systemImage: "checkmark.circle") }

      CompetitionsView(store: store)
        .tabItem { Label("Competitions", systemImage: "trophy") }

      ProfileView(store: store)
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
    }
    .tint(DS.Palette.accent)
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
#else
    TabView {
      TodayView(store: store)
        .tabItem { Label("Today", systemImage: "sun.max") }

      HabitsView(store: store)
        .tabItem { Label("Habits", systemImage: "checkmark.circle") }

      CompetitionsView(store: store)
        .tabItem { Label("Competitions", systemImage: "trophy") }

      ProfileView(store: store)
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
    }
    .tint(DS.Palette.accent)
#endif
  }
}

