import Foundation

#if canImport(HealthKit)
import HealthKit

/// Reads HealthKit data for the current user and produces points based on `GameSettings.scoringMetrics`.
final class HealthKitScoringService {
  enum Error: Swift.Error {
    case healthKitUnavailable
    case notAuthorized
    case missingType
  }

  private let store = HKHealthStore()

  var isAvailable: Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  func requestAuthorization(for metrics: [ScoreMetric]) async throws {
    guard isAvailable else { throw Error.healthKitUnavailable }

    var read: Set<HKObjectType> = []

    for metric in metrics {
      switch metric {
      case .steps:
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { read.insert(t) }
      case .activeEnergyBurned:
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(t) }
      case .sleepScore:
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(t) }
      }
    }

    try await store.requestAuthorization(toShare: [], read: read)
  }

  /// Returns points for the current user, based on selected metrics within a window.
  func points(metrics: [ScoreMetric], start: Date, end: Date) async throws -> Double {
    guard isAvailable else { throw Error.healthKitUnavailable }
    let metrics = metrics.isEmpty ? [.steps] : metrics

    var total: Double = 0
    for metric in metrics {
      switch metric {
      case .steps:
        total += try await steps(start: start, end: end)
      case .activeEnergyBurned:
        total += try await activeEnergyKcal(start: start, end: end)
      case .sleepScore:
        total += try await sleepScore(start: start, end: end)
      }
    }
    return total
  }

  private func steps(start: Date, end: Date) async throws -> Double {
    guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { throw Error.missingType }
    return try await sumQuantity(type: type, unit: .count(), start: start, end: end)
  }

  private func activeEnergyKcal(start: Date, end: Date) async throws -> Double {
    guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { throw Error.missingType }
    return try await sumQuantity(type: type, unit: .kilocalorie(), start: start, end: end)
  }

  /// “Sleep score” is computed from sleep duration as: score = min(100, (hours / 8) * 100)
  private func sleepScore(start: Date, end: Date) async throws -> Double {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { throw Error.missingType }
    let seconds = try await sleepSeconds(type: type, start: start, end: end)
    let hours = seconds / 3600.0
    return min(100, (hours / 8.0) * 100.0)
  }

  private func sumQuantity(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    return try await withCheckedThrowingContinuation { cont in
      let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, result, error in
        if let error { cont.resume(throwing: error); return }
        let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
        cont.resume(returning: sum)
      }
      store.execute(query)
    }
  }

  private func sleepSeconds(type: HKCategoryType, start: Date, end: Date) async throws -> Double {
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    return try await withCheckedThrowingContinuation { cont in
      let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error { cont.resume(throwing: error); return }
        guard let samples = samples as? [HKCategorySample] else {
          cont.resume(returning: 0)
          return
        }

        var total: Double = 0
        for s in samples {
          // Count only "asleep" categories.
          if s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
          {
            // Clamp to window.
            let st = max(s.startDate, start)
            let en = min(s.endDate, end)
            if en > st {
              total += en.timeIntervalSince(st)
            }
          }
        }
        cont.resume(returning: total)
      }
      store.execute(q)
    }
  }
}

#else

/// Stub for non-iOS platforms (keeps the project buildable in previews where HealthKit isn't available).
final class HealthKitScoringService {
  enum Error: Swift.Error { case healthKitUnavailable }
  var isAvailable: Bool { false }
  func requestAuthorization(for metrics: [ScoreMetric]) async throws { throw Error.healthKitUnavailable }
  func points(metrics: [ScoreMetric], start: Date, end: Date) async throws -> Double { throw Error.healthKitUnavailable }
}

#endif

