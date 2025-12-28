import SwiftUI

struct OnboardingView: View {
  @Bindable var store: AppStore

  var body: some View {
    NavigationStack {
      if !store.isSignedIn {
        SignInView(store: store)
      } else if !store.hasProfile {
        ProfileSetupView(store: store)
      } else {
        Text("Loading…")
      }
    }
  }
}

