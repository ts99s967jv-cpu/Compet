import SwiftUI

struct MainTabView: View {
  @Bindable var store: AppStore

  var body: some View {
    TabView {
      FriendsView(store: store)
        .tabItem { Label("Friends", systemImage: "person.2") }

      InvitesView(store: store)
        .tabItem { Label("Games", systemImage: "flag.checkered") }

      SettingsView(store: store)
        .tabItem { Label("Settings", systemImage: "gearshape") }
    }
  }
}

