import SwiftUI

struct RootView: View {
  @Bindable var store: AppStore

  private var preferredScheme: ColorScheme? {
    switch store.theme {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var body: some View {
    Group {
      if !store.isSignedIn || !store.hasProfile {
        OnboardingView(store: store)
      } else {
        MainTabView(store: store)
      }
    }
    .preferredColorScheme(preferredScheme)
  }
}

