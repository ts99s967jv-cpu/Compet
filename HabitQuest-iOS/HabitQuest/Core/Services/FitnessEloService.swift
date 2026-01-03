import Foundation

@MainActor
final class FitnessEloService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func refresh(now: Date = Date()) async -> Int? {
    guard var profile = store.profile else { return nil }
    if store.didMigrateFitnessEloV2 == false, profile.fitnessElo >= 0, profile.fitnessElo <= 3000 {
      let old = profile.fitnessElo
      profile.fitnessElo = Int(FitnessRatingMigration.v1ScoreToV2Elo(old).rounded())
      store.didMigrateFitnessEloV2 = true
      store.fitnessEloConfidenceOverride = 0.5
    }

    let currentElo = Double(profile.fitnessElo)
    var summaries: [FitnessMetric: FitnessRatingEngine.MetricSummary] = [:]

    if profile.hasFitnessTracker {
      do {
        let hk = HealthKitFitnessEloService()
        try await hk.requestAuthorization()
        let result = try await hk.compute(now: now)
        summaries = result.metrics
      } catch {
        summaries = [:]
      }
    }

    let outputs = FitnessRatingEngine.compute(
      inputs: .init(age: profile.age, currentElo: currentElo, metrics: summaries, now: now)
    )

    if let ts = profile.fitnessEloUpdatedAt,
       now.timeIntervalSince(ts) < FitnessRatingConstants.minEloUpdateIntervalSeconds
    {
      var snapshot = outputs.rating
      snapshot.elo = currentElo
      store.fitnessRatingSnapshot = snapshot
      store.saveAll()
      return profile.fitnessElo
    }

    var rating = outputs.rating
    if let floor = store.fitnessEloConfidenceOverride {
      if rating.confidence < floor {
        let k = FitnessRatingEngine.adaptiveK(
          baseK: FitnessRatingConstants.baseK,
          confidence: floor,
          dataConsistency: outputs.dataConsistency,
          shockFactor: FitnessRatingEngine.healthShockFactor(metrics: summaries)
        )
        rating.elo = currentElo + (k * (outputs.actualFPS - outputs.expectedFPS))
        rating.confidence = floor
      } else {
        store.fitnessEloConfidenceOverride = nil
      }
    }

    profile.fitnessElo = Int(rating.elo.rounded())
    profile.fitnessEloUpdatedAt = now
    store.profile = profile
    store.fitnessRatingSnapshot = rating
    store.recordFitnessElo(elo: profile.fitnessElo, at: now)
    store.saveAll()

    if Backend.shared.isAvailable {
      try? await Backend.shared.upsertMyProfile(profile)
    }

    return profile.fitnessElo
  }

  /// Refreshes ELO only if it hasn't been computed in the last `interval` seconds.
  /// Keeps the manual refresh button behavior (this is additive).
  func refreshIfNeeded(now: Date = Date(), interval: TimeInterval = 24 * 60 * 60) async -> Int? {
    guard let profile = store.profile else { return nil }
    if let ts = profile.fitnessEloUpdatedAt, now.timeIntervalSince(ts) < interval {
      return profile.fitnessElo
    }
    return await refresh(now: now)
  }

  func recommendedMatchRange(elo: Int) -> ClosedRange<Int> {
    let c = store.fitnessRatingSnapshot?.confidence ?? FitnessRatingConstants.confidenceMin
    let delta = Int((260.0 - 120.0 * c).rounded())
    return (elo - delta)...(elo + delta)
  }

  func agePercentileRank(elo: Int, age: Int) -> Double {
    let cohort = AgeCohort.forAge(age)
    let mu = FitnessRatingEngine.cohortMeanElo(cohort)
    return FitnessRatingEngine.expectedFPS(elo: Double(elo), muAge: mu, sigma: FitnessRatingConstants.sigmaExpectedFPS)
  }

  func tier(elo: Int, age: Int) -> String {
    let p = agePercentileRank(elo: elo, age: age)
    switch p {
    case ..<0.20: return "Bronze"
    case ..<0.40: return "Silver"
    case ..<0.60: return "Gold"
    case ..<0.80: return "Platinum"
    default: return "Diamond"
    }
  }
}

