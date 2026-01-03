import Foundation

#if canImport(HealthKit)
import HealthKit

/// v2: HealthKit sampler for the Fitness Rating engine.
///
/// This file keeps its historical name for project compatibility, but it no longer implements
/// v1 logic (fixed ranges, 0–3000 cap, nil-score states).
final class HealthKitFitnessEloService {
  enum Error: Swift.Error {
    case healthKitUnavailable
    case missingType
  }

  private let store = HKHealthStore()

  var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  struct Result {
    /// Summaries keyed by metric. Missing metrics are absent (excluded from FPS).
    var metrics: [FitnessMetric: FitnessRatingEngine.MetricSummary]
    var computedAt: Date
  }

  func requestAuthorization() async throws {
    guard isAvailable else { throw Error.healthKitUnavailable }

    var read: Set<HKObjectType> = []
    if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { read.insert(t) }
    if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .vo2Max) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { read.insert(t) }

    try await store.requestAuthorization(toShare: [], read: read)
  }

  /// v2: fetches summaries over the configured window.
  func compute(now: Date = Date()) async throws -> Result {
    guard isAvailable else { throw Error.healthKitUnavailable }

    let windowDays = FitnessRatingConstants.metricWindowDays
    let end = now
    let endDay = Calendar.current.startOfDay(for: end)
    let start = Calendar.current.date(byAdding: .day, value: -(windowDays - 1), to: endDay)
      ?? end.addingTimeInterval(TimeInterval(-(windowDays - 1) * 24 * 3600))

    let metrics = try await fetchMetricSummaries(start: start, end: end, windowDays: windowDays)
    return Result(metrics: metrics, computedAt: now)
  }

  private func fetchMetricSummaries(start: Date, end: Date, windowDays: Int) async throws -> [FitnessMetric: FitnessRatingEngine.MetricSummary] {
    async let steps = fetchDailyCumulative(metric: .steps, quantityID: .stepCount, unit: .count(), start: start, end: end, windowDays: windowDays)
    async let sleep = fetchDailySleepHours(metric: .sleepDuration, start: start, end: end, windowDays: windowDays)
    async let rhr = fetchDailyDiscreteAverage(metric: .restingHeartRate, quantityID: .restingHeartRate, unit: .count().unitDivided(by: .minute()), start: start, end: end, windowDays: windowDays)
    async let hrv = fetchDailyDiscreteAverage(metric: .hrvSDNN, quantityID: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end, windowDays: windowDays)
    async let vo2 = fetchLatestQuantity(metric: .vo2Max, quantityID: .vo2Max, unit: HKUnit(from: "ml/kg*min"), start: start, end: end, windowDays: windowDays)
    async let spo2 = fetchDailyDiscreteAverage(metric: .spO2, quantityID: .oxygenSaturation, unit: .percent(), start: start, end: end, windowDays: windowDays)
    async let rr = fetchDailyDiscreteAverage(metric: .respiratoryRate, quantityID: .respiratoryRate, unit: .count().unitDivided(by: .minute()), start: start, end: end, windowDays: windowDays)

    let results = try await [steps, sleep, rhr, hrv, vo2, spo2, rr].compactMap { $0 }
    var out: [FitnessMetric: FitnessRatingEngine.MetricSummary] = [:]
    for (m, s) in results { out[m] = s }
    return out
  }

  private func fetchDailyCumulative(
    metric: FitnessMetric,
    quantityID: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date,
    windowDays: Int
  ) async throws -> (FitnessMetric, FitnessRatingEngine.MetricSummary)? {
    guard let type = HKObjectType.quantityType(forIdentifier: quantityID) else { throw Error.missingType }

    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let interval = DateComponents(day: 1)
    let anchor = Calendar.current.startOfDay(for: end)

    let daily: [Double] = try await withCheckedThrowingContinuation { cont in
      let q = HKStatisticsCollectionQuery(
        quantityType: type,
        quantitySamplePredicate: pred,
        options: .cumulativeSum,
        anchorDate: anchor,
        intervalComponents: interval
      )
      q.initialResultsHandler = { _, results, error in
        if let error { cont.resume(throwing: error); return }
        guard let results else { cont.resume(returning: []); return }
        var xs: [Double] = []
        results.enumerateStatistics(from: start, to: end) { stat, _ in
          xs.append(stat.sumQuantity()?.doubleValue(for: unit) ?? 0)
        }
        cont.resume(returning: xs)
      }
      store.execute(q)
    }

    let daysPresent = daily.filter { $0 > 0 }.count
    guard daysPresent > 0 else { return nil }
    let avg = daily.reduce(0, +) / Double(max(1, windowDays))
    return (metric, .init(value: avg, daysPresent: daysPresent, windowDays: windowDays, dailyValues: daily))
  }

  private func fetchDailyDiscreteAverage(
    metric: FitnessMetric,
    quantityID: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date,
    windowDays: Int
  ) async throws -> (FitnessMetric, FitnessRatingEngine.MetricSummary)? {
    guard let type = HKObjectType.quantityType(forIdentifier: quantityID) else { throw Error.missingType }

    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let interval = DateComponents(day: 1)
    let anchor = Calendar.current.startOfDay(for: end)

    let daily: [Double?] = try await withCheckedThrowingContinuation { cont in
      let q = HKStatisticsCollectionQuery(
        quantityType: type,
        quantitySamplePredicate: pred,
        options: .discreteAverage,
        anchorDate: anchor,
        intervalComponents: interval
      )
      q.initialResultsHandler = { _, results, error in
        if let error { cont.resume(throwing: error); return }
        guard let results else { cont.resume(returning: []); return }
        var xs: [Double?] = []
        results.enumerateStatistics(from: start, to: end) { stat, _ in
          xs.append(stat.averageQuantity()?.doubleValue(for: unit))
        }
        cont.resume(returning: xs)
      }
      store.execute(q)
    }

    let present = daily.compactMap { $0 }
    guard !present.isEmpty else { return nil }

    let daysPresent = daily.filter { $0 != nil }.count
    let avg = present.reduce(0, +) / Double(present.count)
    let dailyValues = daily.map { $0 ?? avg }
    return (metric, .init(value: avg, daysPresent: daysPresent, windowDays: windowDays, dailyValues: dailyValues))
  }

  private func fetchLatestQuantity(
    metric: FitnessMetric,
    quantityID: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date,
    windowDays: Int
  ) async throws -> (FitnessMetric, FitnessRatingEngine.MetricSummary)? {
    guard let type = HKObjectType.quantityType(forIdentifier: quantityID) else { throw Error.missingType }
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

    let sample: HKQuantitySample? = try await withCheckedThrowingContinuation { cont in
      let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: [sort]) { _, samples, error in
        if let error { cont.resume(throwing: error); return }
        cont.resume(returning: (samples as? [HKQuantitySample])?.first)
      }
      store.execute(q)
    }
    guard let sample else { return nil }
    let v = sample.quantity.doubleValue(for: unit)
    return (metric, .init(value: v, daysPresent: 1, windowDays: windowDays, dailyValues: [v]))
  }

  private func fetchDailySleepHours(
    metric: FitnessMetric,
    start: Date,
    end: Date,
    windowDays: Int
  ) async throws -> (FitnessMetric, FitnessRatingEngine.MetricSummary)? {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { throw Error.missingType }
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
      let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error { cont.resume(throwing: error); return }
        cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
      }
      store.execute(q)
    }

    var byDaySeconds: [Date: Double] = [:]
    for s in samples {
      let isAsleep =
        s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        || s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
        || s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        || s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
      guard isAsleep else { continue }

      let st = max(s.startDate, start)
      let en = min(s.endDate, end)
      guard en > st else { continue }

      let day = Calendar.current.startOfDay(for: st)
      byDaySeconds[day, default: 0] += en.timeIntervalSince(st)
    }
    guard !byDaySeconds.isEmpty else { return nil }

    let daysPresent = byDaySeconds.count
    var daily: [Double] = []
    var cursor = Calendar.current.startOfDay(for: start)
    let endDay = Calendar.current.startOfDay(for: end)
    while cursor <= endDay {
      daily.append((byDaySeconds[cursor] ?? 0) / 3600.0)
      guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }
    let avg = daily.reduce(0, +) / Double(max(1, windowDays))
    return (metric, .init(value: avg, daysPresent: daysPresent, windowDays: windowDays, dailyValues: daily))
  }
}

#else

/// Stub for non-iOS platforms.
final class HealthKitFitnessEloService {
  struct Result { var metrics: [FitnessMetric: FitnessRatingEngine.MetricSummary]; var computedAt: Date }
  enum Error: Swift.Error { case healthKitUnavailable }
  func requestAuthorization() async throws { throw Error.healthKitUnavailable }
  func compute(now: Date = Date()) async throws -> Result { throw Error.healthKitUnavailable }
}

#endif

