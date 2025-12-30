import Foundation

#if canImport(HealthKit)
import HealthKit

/// Computes a "Fitness ELO" (0-3000) from historical HealthKit trends.
///
/// Notes:
/// - This is a local prototype intended to be "fair-ish" without a global population baseline.
/// - It normalizes each metric into a 0...1 band using pragmatic health ranges, then blends with weights.
/// - Designed to be used only when the user has a fitness tracker.
final class HealthKitFitnessEloService {
  enum Error: Swift.Error {
    case healthKitUnavailable
    case missingType
  }

  private let store = HKHealthStore()

  var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  struct Inputs {
    var avgDailySteps28d: Double?
    var avgSleepHours28d: Double?
    var avgRestingHr28d: Double?
    var avgHrvMs28d: Double?
    var latestVo2Max: Double?
    var avgSpO2_28d: Double?
    var avgRespRate28d: Double?
  }

  struct Result {
    var elo: Int
    var breakdown: [String: Double]
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

  /// Computes ELO (0-3000) using last 28 days of data and latest VO2 max.
  func compute(age: Int, gender: Gender, now: Date = Date()) async throws -> Result {
    guard isAvailable else { throw Error.healthKitUnavailable }

    let start = Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now.addingTimeInterval(-28 * 24 * 3600)
    let end = now

    let inputs = try await fetchInputs(start: start, end: end)
    let (elo, breakdown) = score(inputs: inputs, age: age, gender: gender)

    return Result(elo: elo, breakdown: breakdown, computedAt: now)
  }

  // MARK: - Scoring

  private func score(inputs: Inputs, age: Int, gender: Gender) -> (Int, [String: Double]) {
    // Normalize each metric to 0...1 then weighted average.
    var parts: [String: Double] = [:]

    let steps = scoreLinear(inputs.avgDailySteps28d, lower: 2_000, upper: 15_000)
    parts["steps"] = steps

    let sleep = scoreBell(inputs.avgSleepHours28d, center: 8.0, tolerance: 3.0) // best near 8h
    parts["sleep"] = sleep

    // Resting HR: lower is generally better (within reason). Best ~50-60, clamp to 40-100.
    let rhr = scoreLinear(inputs.avgRestingHr28d, lower: 40, upper: 100, invert: true)
    parts["resting_hr"] = rhr

    // HRV SDNN: higher is better. Typical 20-120ms.
    let hrv = scoreLinear(inputs.avgHrvMs28d, lower: 20, upper: 120)
    parts["hrv"] = hrv

    // VO2 max: normalize against age/gender expected bands.
    let vo2 = scoreVo2(inputs.latestVo2Max, age: age, gender: gender)
    parts["vo2max"] = vo2

    // SpO2: typical 95-100%. Use 90-100 clamp.
    let spo2 = scoreLinear(inputs.avgSpO2_28d, lower: 0.90, upper: 0.99)
    parts["spo2"] = spo2

    // Respiratory rate: best near ~16 breaths/min. Penalize far from center.
    let rr = scoreBell(inputs.avgRespRate28d, center: 16, tolerance: 6) // 10-22 reasonable
    parts["resp_rate"] = rr

    // Weights: lean on durable trends (steps, sleep) and cardiorespiratory fitness (VO2, RHR, HRV).
    let weights: [(String, Double)] = [
      ("steps", 0.22),
      ("sleep", 0.16),
      ("resting_hr", 0.18),
      ("hrv", 0.14),
      ("vo2max", 0.18),
      ("spo2", 0.06),
      ("resp_rate", 0.06),
    ]

    // Missing values: down-weight missing metrics and renormalize.
    var weightedSum: Double = 0
    var weightSum: Double = 0
    for (k, w) in weights {
      guard let v = parts[k] else { continue }
      if v.isNaN { continue }
      weightedSum += v * w
      weightSum += w
    }
    let composite = weightSum > 0 ? (weightedSum / weightSum) : 0
    let elo = Int((composite * 3000).rounded())

    parts["composite"] = composite
    return (Swift.min(3000, Swift.max(0, elo)), parts)
  }

  private func scoreLinear(_ value: Double?, lower: Double, upper: Double, invert: Bool = false) -> Double {
    guard let value else { return .nan }
    guard upper > lower else { return .nan }
    let t = (value - lower) / (upper - lower)
    let clamped = Swift.max(0, Swift.min(1, t))
    return invert ? (1 - clamped) : clamped
  }

  /// Peaks at center (score 1) and falls off linearly to 0 at center +/- tolerance.
  private func scoreBell(_ value: Double?, center: Double, tolerance: Double) -> Double {
    guard let value else { return .nan }
    guard tolerance > 0 else { return .nan }
    let d = abs(value - center)
    return max(0, 1 - (d / tolerance))
  }

  private func scoreVo2(_ value: Double?, age: Int, gender: Gender) -> Double {
    guard let value else { return .nan }
    let a = max(13, min(90, age))

    // Rough expected bands (ml/kg/min). These are intentionally conservative.
    let expected: Double
    let spread: Double
    switch gender {
    case .female:
      expected = max(18, 42 - 0.30 * Double(max(0, a - 20)))
      spread = 12
    case .male:
      expected = max(20, 50 - 0.35 * Double(max(0, a - 20)))
      spread = 14
    case .nonBinary, .preferNotToSay:
      expected = max(19, 46 - 0.33 * Double(max(0, a - 20)))
      spread = 13
    }

    // Map [expected - spread, expected + spread] to [0, 1].
    return scoreLinear(value, lower: expected - spread, upper: expected + spread)
  }

  // MARK: - Fetch

  private func fetchInputs(start: Date, end: Date) async throws -> Inputs {
    async let steps = avgDailySteps(start: start, end: end)
    async let sleep = avgSleepHours(start: start, end: end)
    async let rhr = avgQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()), start: start, end: end)
    async let hrv = avgQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end)
    async let vo2 = latestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"), start: start, end: end)
    async let spo2 = avgQuantity(.oxygenSaturation, unit: .percent(), start: start, end: end)
    async let rr = avgQuantity(.respiratoryRate, unit: .count().unitDivided(by: .minute()), start: start, end: end)

    return try await Inputs(
      avgDailySteps28d: steps,
      avgSleepHours28d: sleep,
      avgRestingHr28d: rhr,
      avgHrvMs28d: hrv,
      latestVo2Max: vo2,
      avgSpO2_28d: spo2,
      avgRespRate28d: rr
    )
  }

  private func avgDailySteps(start: Date, end: Date) async throws -> Double? {
    guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { throw Error.missingType }
    let sum = try await sumQuantity(type: type, unit: .count(), start: start, end: end)
    let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 28)
    return sum / Double(days)
  }

  private func avgSleepHours(start: Date, end: Date) async throws -> Double? {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { throw Error.missingType }
    let seconds = try await sleepSeconds(type: type, start: start, end: end)
    let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 28)
    return (seconds / 3600.0) / Double(days)
  }

  private func avgQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
    guard let type = HKObjectType.quantityType(forIdentifier: id) else { throw Error.missingType }
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    return try await withCheckedThrowingContinuation { cont in
      let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .discreteAverage) { _, result, error in
        if let error { cont.resume(throwing: error); return }
        let v = result?.averageQuantity()?.doubleValue(for: unit)
        cont.resume(returning: v)
      }
      store.execute(q)
    }
  }

  private func latestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
    guard let type = HKObjectType.quantityType(forIdentifier: id) else { throw Error.missingType }
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

    return try await withCheckedThrowingContinuation { cont in
      let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: [sort]) { _, samples, error in
        if let error { cont.resume(throwing: error); return }
        let sample = (samples as? [HKQuantitySample])?.first
        cont.resume(returning: sample?.quantity.doubleValue(for: unit))
      }
      store.execute(q)
    }
  }

  private func sumQuantity(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    return try await withCheckedThrowingContinuation { cont in
      let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, result, error in
        if let error { cont.resume(throwing: error); return }
        let v = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
        cont.resume(returning: v)
      }
      store.execute(q)
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
          if s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            || s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
          {
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

/// Stub for non-iOS platforms.
final class HealthKitFitnessEloService {
  struct Result { var elo: Int; var breakdown: [String: Double]; var computedAt: Date }
  enum Error: Swift.Error { case healthKitUnavailable }
  func requestAuthorization() async throws { throw Error.healthKitUnavailable }
  func compute(age: Int, gender: Gender, now: Date = Date()) async throws -> Result { throw Error.healthKitUnavailable }
}

#endif

