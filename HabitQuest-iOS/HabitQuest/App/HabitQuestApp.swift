import SwiftUI

@main
struct HabitQuestApp: App {
  @State private var store = AppStore()

  var body: some Scene {
    WindowGroup {
      RootView(store: store)
    }
  }
}

