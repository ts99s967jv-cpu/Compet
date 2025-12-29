import Foundation

/// In-memory KeyValueStore for SwiftUI previews/tests.
final class InMemoryStore: KeyValueStore {
  private var storage: [String: Data] = [:]

  func data(forKey key: String) -> Data? {
    storage[key]
  }

  func set(_ data: Data?, forKey key: String) {
    storage[key] = data
  }
}

