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
    // Sync whenever the signed-in account changes (incl. sign-in after sign-out).
    .task(id: store.account?.userID) {
      guard store.isSignedIn else { return }
      await BackendSyncService(store: store).syncAll()
      // Request HealthKit permissions up-front once (avoids tab-by-tab prompts).
      if !store.didRequestHealthKitAuthorization {
        do {
          try await HealthKitAuthorizationService().requestAllAuthorization()
          store.didRequestHealthKitAuthorization = true
          store.saveAll()
        } catch {
          // Don't block app usage; user may deny permissions.
        }
      }
      // Request Notifications permission once (optional; enables device alerts for inbox items).
      await LocalNotificationService.shared.requestAuthorizationIfNeeded(store: store)
    }
  }
}

