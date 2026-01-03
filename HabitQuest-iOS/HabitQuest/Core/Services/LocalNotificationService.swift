import Foundation

#if canImport(UserNotifications)
import UserNotifications

@MainActor
final class LocalNotificationService {
  static let shared = LocalNotificationService()

  private init() {}

  func requestAuthorizationIfNeeded(store: AppStore) async {
    guard !store.didRequestNotificationAuthorization else { return }
    do {
      let center = UNUserNotificationCenter.current()
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      store.didRequestNotificationAuthorization = true
      store.saveAll()
      if granted {
        // No-op: we only post when new events occur.
      }
    } catch {
      store.didRequestNotificationAuthorization = true
      store.saveAll()
    }
  }

  nonisolated func postIfAllowed(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    // Fire immediately.
    let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(req)
  }
}

#else

@MainActor
final class LocalNotificationService {
  static let shared = LocalNotificationService()
  private init() {}
  func requestAuthorizationIfNeeded(store: AppStore) async {}
  nonisolated func postIfAllowed(title: String, body: String) {}
}

#endif

