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

  /// Refreshes ELO only if it hasn't been computed in the last `interval` seconds.
  /// Keeps the manual refresh button behavior (this is additive).
  func refreshIfNeeded(now: Date = Date(), interval: TimeInterval = 24 * 60 * 60) async -> Int? {
    guard let profile = store.profile else { return nil }
    guard profile.hasFitnessTracker else { return await refresh(now: now) }

    if let ts = profile.fitnessEloUpdatedAt, now.timeIntervalSince(ts) < interval {
      return profile.fitnessElo
    }
    return await refresh(now: now)
  }

  func recommendedMatchRange(elo: Int) -> ClosedRange<Int> {
    // Chess-like: tighter at higher confidence. Prototype: +/- 200.
    let delta = 200
    return max(0, elo - delta)...min(3000, elo + delta)
  }
}

