import SwiftUI

@main
struct HabitQuestApp: App {
  @State private var store = AppStore()

  var body: some Scene {
    WindowGroup {
      RootView(store: store)
        .onOpenURL { url in
          guard Backend.shared.isAvailable,
                let redirect = BackendConfig.supabaseRedirectURL,
                url.scheme == redirect.scheme else { return }
          Task { await handleAuthCallback(url: url) }
        }
    }
  }

  @MainActor
  private func handleAuthCallback(url: URL) async {
    do {
      let userID = try await Backend.shared.handleAuthCallback(url: url)
      let email = store.pendingAuthEmail ?? store.account?.email ?? ""
      store.account = Account(
        userID: userID,
        email: email,
        username: store.account?.username ?? "",
        createdAt: Date()
      )
      store.profile = try await Backend.shared.fetchMyProfile()
      store.pendingAuthEmail = nil
      store.saveAll()
      await BackendSyncService(store: store).syncAll()
    } catch {
      // If callback fails, keep local state unchanged.
    }
  }
}

