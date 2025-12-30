import Foundation

#if canImport(HealthKit)
import HealthKit

struct HealthTrendPoint: Identifiable, Equatable {
  var id: Date { day }
  /// Start-of-day timestamp in the user's current calendar.
  let day: Date
  /// Metric value for that day (0 if missing).
  let value: Double
}

struct HealthTrendsSnapshot: Equatable {
  var steps: [HealthTrendPoint] = []
  var activeEnergyKcal: [HealthTrendPoint] = []
  var workouts: [HealthTrendPoint] = []
  var sleepHours: [HealthTrendPoint] = []
}

/// Reads HealthKit data and produces daily time-series for Profile "Health stats".
final class HealthKitTrendsService {
  enum Error: Swift.Error {
    case healthKitUnavailable
    case missingType
  }

  private let store = HKHealthStore()

  var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  func requestAuthorization() async throws {
    guard isAvailable else { throw Error.healthKitUnavailable }

    var read: Set<HKObjectType> = []
    if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(t) }
    read.insert(HKObjectType.workoutType())
    if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(t) }
    try await store.requestAuthorization(toShare: [], read: read)
  }

  /// Fetches daily trend series (latest first) for a handful of HealthKit metrics.
  ///
  /// - Note: This intentionally fills missing days with 0.
  func fetch(daysBack: Int = 365, calendar: Calendar = .current, now: Date = Date()) async throws -> HealthTrendsSnapshot {
    guard isAvailable else { throw Error.healthKitUnavailable }

    let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
    let start = calendar.date(byAdding: .day, value: -(max(28, daysBack) - 1), to: calendar.startOfDay(for: now)) ?? now

    async let steps = dailyCumulativeSum(
      identifier: .stepCount,
      unit: .count(),
      start: start,
      end: end,
      calendar: calendar
    )
    async let energy = dailyCumulativeSum(
      identifier: .activeEnergyBurned,
      unit: .kilocalorie(),
      start: start,
      end: end,
      calendar: calendar
    )
    async let workouts = dailyWorkoutCount(start: start, end: end, calendar: calendar)
    async let sleep = dailySleepHours(start: start, end: end, calendar: calendar)

    var snap = HealthTrendsSnapshot(
      steps: try await steps,
      activeEnergyKcal: try await energy,
      workouts: try await workouts,
      sleepHours: try await sleep
    )

    // Trim endless older zeros, but keep at least 28 days for swipe panels.
    snap.steps = trimOlderZeros(points: snap.steps, minDays: 28)
    snap.activeEnergyKcal = trimOlderZeros(points: snap.activeEnergyKcal, minDays: 28)
    snap.workouts = trimOlderZeros(points: snap.workouts, minDays: 28)
    snap.sleepHours = trimOlderZeros(points: snap.sleepHours, minDays: 28)
    return snap
  }

  // MARK: - Internals

  private func dailyCumulativeSum(
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date,
    calendar: Calendar
  ) async throws -> [HealthTrendPoint] {
    guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { throw Error.missingType }

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
          cont.resume(returning: self.zeroSeries(start: start, end: end, calendar: calendar))
          return
        }

        var byDay: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
          let v = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
          byDay[calendar.startOfDay(for: stats.startDate)] = v
        }
        cont.resume(returning: self.completeSeries(byDay: byDay, start: start, end: end, calendar: calendar))
      }
      self.store.execute(q)
    }
  }

  private func dailyWorkoutCount(start: Date, end: Date, calendar: Calendar) async throws -> [HealthTrendPoint] {
    let type = HKObjectType.workoutType()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    let byDay: [Date: Double] = try await withCheckedThrowingContinuation { cont in
      let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error { cont.resume(throwing: error); return }
        guard let samples = samples as? [HKWorkout] else { cont.resume(returning: [:]); return }
        var map: [Date: Double] = [:]
        for s in samples {
          let d = calendar.startOfDay(for: s.startDate)
          map[d, default: 0] += 1
        }
        cont.resume(returning: map)
      }
      store.execute(q)
    }

    return completeSeries(byDay: byDay, start: start, end: end, calendar: calendar)
  }

  private func dailySleepHours(start: Date, end: Date, calendar: Calendar) async throws -> [HealthTrendPoint] {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { throw Error.missingType }
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    let byDaySeconds: [Date: Double] = try await withCheckedThrowingContinuation { cont in
      let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error { cont.resume(throwing: error); return }
        guard let samples = samples as? [HKCategorySample] else { cont.resume(returning: [:]); return }

        var map: [Date: Double] = [:]
        for s in samples {
          // Count only "asleep" categories.
          if s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
          {
            // Clamp to window.
            let st0 = max(s.startDate, start)
            let en0 = min(s.endDate, end)
            if en0 <= st0 { continue }

            // Allocate across days if needed.
            var cursor = st0
            while cursor < en0 {
              let dayStart = calendar.startOfDay(for: cursor)
              guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
              let segEnd = min(en0, nextDay)
              let sec = segEnd.timeIntervalSince(cursor)
              map[dayStart, default: 0] += sec
              cursor = segEnd
            }
          }
        }

        cont.resume(returning: map)
      }
      store.execute(q)
    }

    let byDayHours = byDaySeconds.mapValues { $0 / 3600.0 }
    return completeSeries(byDay: byDayHours, start: start, end: end, calendar: calendar)
  }

  private func completeSeries(byDay: [Date: Double], start: Date, end: Date, calendar: Calendar) -> [HealthTrendPoint] {
    var points: [HealthTrendPoint] = []
    var day = calendar.startOfDay(for: start)
    let endDayExclusive = calendar.startOfDay(for: end)

    while day < endDayExclusive {
      points.append(HealthTrendPoint(day: day, value: byDay[day] ?? 0))
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }

    // Latest first (today -> older).
    return points.sorted { $0.day > $1.day }
  }

  private func zeroSeries(start: Date, end: Date, calendar: Calendar) -> [HealthTrendPoint] {
    completeSeries(byDay: [:], start: start, end: end, calendar: calendar)
  }

  private func trimOlderZeros(points: [HealthTrendPoint], minDays: Int) -> [HealthTrendPoint] {
    guard !points.isEmpty else { return points }
    let keepAtLeast = max(1, minDays)
    let newestToOldest = points
    let oldestNonZeroIndex = newestToOldest.lastIndex(where: { abs($0.value) > 0.000_001 })
    let minIndex = keepAtLeast - 1
    let endIndex = max(oldestNonZeroIndex ?? minIndex, minIndex)
    return Array(newestToOldest.prefix(endIndex + 1))
  }
}

#else

struct HealthTrendPoint: Identifiable, Equatable {
  var id: Date { day }
  let day: Date
  let value: Double
}

struct HealthTrendsSnapshot: Equatable {
  var steps: [HealthTrendPoint] = []
  var activeEnergyKcal: [HealthTrendPoint] = []
  var workouts: [HealthTrendPoint] = []
  var sleepHours: [HealthTrendPoint] = []
}

final class HealthKitTrendsService {
  enum Error: Swift.Error { case healthKitUnavailable }
  var isAvailable: Bool { false }
  func requestAuthorization() async throws { throw Error.healthKitUnavailable }
  func fetch(daysBack: Int = 365, calendar: Calendar = .current, now: Date = Date()) async throws -> HealthTrendsSnapshot { throw Error.healthKitUnavailable }
}

#endif

