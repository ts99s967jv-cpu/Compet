import Foundation

#if canImport(HealthKit)
import HealthKit

/// Minimal helper for auto-tracking step-based habits from HealthKit.
final class HealthKitStepSeriesService {
  enum Error: Swift.Error {
    case healthKitUnavailable
    case missingType
  }

  private let store = HKHealthStore()

  var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  func requestAuthorization() async throws {
    guard isAvailable else { throw Error.healthKitUnavailable }
    guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { throw Error.missingType }
    try await store.requestAuthorization(toShare: [], read: [type])
  }

  /// Returns daily steps for the last `daysBack` days (newest first), including today.
  func fetchDailySteps(daysBack: Int = 60, calendar: Calendar = .current, now: Date = Date()) async throws -> [HealthTrendPoint] {
    guard isAvailable else { throw Error.healthKitUnavailable }
    guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { throw Error.missingType }

    let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
    let start = calendar.date(byAdding: .day, value: -(max(1, daysBack) - 1), to: calendar.startOfDay(for: now)) ?? now

    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let anchor = calendar.startOfDay(for: end)
    let interval = DateComponents(day: 1)

    return try await withCheckedThrowingContinuation { cont in
      let q = HKStatisticsCollectionQuery(
        quantityType: type,
        quantitySamplePredicate: pred,
        options: [.cumulativeSum],
        anchorDate: anchor,
        intervalComponents: interval
      )

      q.initialResultsHandler = { _, collection, error in
        if let error { cont.resume(throwing: error); return }
        guard let collection else {
          cont.resume(returning: [])
          return
        }

        var points: [HealthTrendPoint] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
          let v = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
          let d = calendar.startOfDay(for: stats.startDate)
          points.append(HealthTrendPoint(day: d, value: v))
        }

        // Filter out any accidental "tomorrow" bucket and sort newest first.
        let todayStart = calendar.startOfDay(for: now)
        points = points.filter { $0.day <= todayStart }.sorted { $0.day > $1.day }
        cont.resume(returning: points)
      }

      store.execute(q)
    }
  }
}

#else

final class HealthKitStepSeriesService {
  enum Error: Swift.Error { case healthKitUnavailable }
  var isAvailable: Bool { false }
  func requestAuthorization() async throws { throw Error.healthKitUnavailable }
  func fetchDailySteps(daysBack: Int = 60, calendar: Calendar = .current, now: Date = Date()) async throws -> [HealthTrendPoint] { throw Error.healthKitUnavailable }
}

#endif

