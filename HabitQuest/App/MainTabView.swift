import SwiftUI

struct MainTabView: View {
  @Bindable var store: AppStore

  var body: some View {
    TabView {
      TodayView(store: store)
        .tabItem { Label("Today", systemImage: "sun.max") }

      CompetitionsView(store: store)
        .tabItem { Label("Competitions", systemImage: "trophy") }

      ProfileView(store: store)
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
    }
    .tint(DS.Palette.accent)
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
  }
}

