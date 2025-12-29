import Foundation

@MainActor
final class FitnessEloService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  /// Refreshes ELO from HealthKit and stores it on the profile.
  /// Returns the new ELO if computed.
  func refresh(now: Date = Date()) async -> Int? {
    guard var profile = store.profile else { return nil }
    guard profile.hasFitnessTracker else {
      profile.fitnessElo = nil
      profile.fitnessEloUpdatedAt = nil
      store.profile = profile
      store.saveAll()
      return nil
    }

    do {
      let hk = HealthKitFitnessEloService()
      try await hk.requestAuthorization()
      let result = try await hk.compute(age: profile.age, gender: profile.gender, now: now)
      profile.fitnessElo = result.elo
      profile.fitnessEloUpdatedAt = result.computedAt
      store.profile = profile
      store.saveAll()
      return result.elo
    } catch {
      // Leave old value if present; do not crash.
      return profile.fitnessElo
    }
  }

  func recommendedMatchRange(elo: Int) -> ClosedRange<Int> {
    // Chess-like: tighter at higher confidence. Prototype: +/- 200.
    let delta = 200
    return max(0, elo - delta)...min(3000, elo + delta)
  }
}

