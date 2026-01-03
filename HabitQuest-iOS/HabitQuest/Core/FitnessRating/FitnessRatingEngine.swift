import Foundation

enum FitnessRatingEngine {
  struct MetricSummary: Equatable, Codable {
    var value: Double
    var daysPresent: Int
    var windowDays: Int
    var dailyValues: [Double]
  }

  struct Inputs: Equatable, Codable {
    var age: Int
    var currentElo: Double
    var metrics: [FitnessMetric: MetricSummary]
    var now: Date
  }

  struct Outputs: Equatable, Codable {
    var rating: FitnessRating
    var expectedFPS: Double
    var actualFPS: Double
    var kFactor: Double
    var dataCompleteness: Double
    var dataConsistency: Double
    var ageCohort: AgeCohort
    var metricPercentiles: [FitnessMetric: Double]
    var metricConfidences: [FitnessMetric: Double]
  }

  static func compute(inputs: Inputs) -> Outputs {
    let cohort = AgeCohort.forAge(inputs.age)
    let muAge = cohortMeanElo(cohort)
    let expected = expectedFPS(elo: inputs.currentElo, muAge: muAge, sigma: FitnessRatingConstants.sigmaExpectedFPS)

    var pct: [FitnessMetric: Double] = [:]
    var conf: [FitnessMetric: Double] = [:]
    for (m, s) in inputs.metrics {
      let c = metricConfidence(daysPresent: s.daysPresent, windowDays: max(1, s.windowDays))
      guard c > 0 else { continue }
      pct[m] = FitnessNorms.percentile(metric: m, value: s.value, age: inputs.age)
      conf[m] = c
    }

    let actual = fps(
      age: inputs.age,
      currentElo: inputs.currentElo,
      expectedFPS: expected,
      metricPercentiles: pct,
      metricConfidences: conf
    )

    let completeness = dataCompleteness(metricConfidences: conf)
    let consistency = dataConsistency(metrics: inputs.metrics)
    let confidence = overallConfidence(
      now: inputs.now,
      metrics: inputs.metrics,
      dataCompleteness: completeness,
      dataConsistency: consistency
    )

    let k = adaptiveK(
      baseK: FitnessRatingConstants.baseK,
      confidence: confidence,
      dataConsistency: consistency,
      shockFactor: healthShockFactor(metrics: inputs.metrics)
    )

    let nextElo = inputs.currentElo + (k * (actual - expected))

    return Outputs(
      rating: FitnessRating(elo: nextElo, fps: actual, confidence: confidence),
      expectedFPS: expected,
      actualFPS: actual,
      kFactor: k,
      dataCompleteness: completeness,
      dataConsistency: consistency,
      ageCohort: cohort,
      metricPercentiles: pct,
      metricConfidences: conf
    )
  }

  static func expectedFPS(elo: Double, muAge: Double, sigma: Double) -> Double {
    1.0 / (1.0 + exp(-(elo - muAge) / max(1e-6, sigma)))
  }

  static func fps(
    age: Int,
    currentElo: Double,
    expectedFPS: Double,
    metricPercentiles: [FitnessMetric: Double],
    metricConfidences: [FitnessMetric: Double]
  ) -> Double {
    _ = age
    _ = currentElo
    let weights = FitnessRatingConstants.weights
    var num: Double = 0
    var den: Double = 0
    for (m, w) in weights {
      let c = metricConfidences[m] ?? 0
      guard c > 0, let p = metricPercentiles[m] else { continue }
      num += w * p * c
      den += w * c
    }
    if den <= 0 { return expectedFPS }
    return min(1.0, max(0.0, num / den))
  }

  static func metricConfidence(daysPresent: Int, windowDays: Int) -> Double {
    min(1.0, max(0.0, Double(max(0, daysPresent)) / Double(max(1, windowDays))))
  }

  static func adaptiveK(baseK: Double, confidence: Double, dataConsistency: Double, shockFactor: Double) -> Double {
    max(0.0, baseK * confidence * dataConsistency * shockFactor)
  }

  static func cohortMeanElo(_ cohort: AgeCohort) -> Double {
    _ = cohort
    return FitnessRatingConstants.defaultCohortMeanElo
  }

  static func dataCompleteness(metricConfidences: [FitnessMetric: Double]) -> Double {
    let weights = FitnessRatingConstants.weights
    var num: Double = 0
    var den: Double = 0
    for (m, w) in weights {
      den += w
      num += w * (metricConfidences[m] ?? 0)
    }
    if den <= 0 { return 0 }
    return min(1.0, max(0.0, num / den))
  }

  static func dataConsistency(metrics: [FitnessMetric: MetricSummary]) -> Double {
    var penalties: [Double] = []
    if let steps = metrics[.steps], steps.dailyValues.count >= 7 {
      let cv = coefficientOfVariation(steps.dailyValues)
      penalties.append(mapClamp(value: cv, inMin: 0.2, inMax: 0.6, outMin: 0.0, outMax: 0.5))
    }
    if let rhr = metrics[.restingHeartRate], rhr.dailyValues.count >= 7 {
      let sd = standardDeviation(rhr.dailyValues)
      penalties.append(mapClamp(value: sd, inMin: 3.0, inMax: 8.0, outMin: 0.0, outMax: 0.5))
    }
    let penalty = min(0.5, penalties.reduce(0.0, +))
    return min(1.0, max(0.5, 1.0 - penalty))
  }

  static func overallConfidence(
    now: Date,
    metrics: [FitnessMetric: MetricSummary],
    dataCompleteness: Double,
    dataConsistency: Double
  ) -> Double {
    let days = daysWithAnyData(metrics: metrics, now: now)
    let ramp = min(1.0, Double(days) / Double(max(1, FitnessRatingConstants.fullConfidenceTargetDays)))
    let value = FitnessRatingConstants.confidenceMin + 0.85 * (ramp * dataCompleteness * dataConsistency)
    return FitnessRating.clampConfidence(value)
  }

  static func healthShockFactor(metrics: [FitnessMetric: MetricSummary]) -> Double {
    var factor: Double = 1.0
    if let rhr = metrics[.restingHeartRate] {
      if isSpike(series: rhr.dailyValues, recentDays: 7, baselineDays: 21, mode: .increase, thresholdAbs: 8.0, thresholdRel: 0.12) {
        factor = min(factor, 0.35)
      }
    }
    if let hrv = metrics[.hrvSDNN] {
      if isSpike(series: hrv.dailyValues, recentDays: 7, baselineDays: 21, mode: .decrease, thresholdAbs: 10.0, thresholdRel: 0.20) {
        factor = min(factor, 0.35)
      }
    }
    if let steps = metrics[.steps] {
      if isSpike(series: steps.dailyValues, recentDays: 7, baselineDays: 21, mode: .decrease, thresholdAbs: 2_500, thresholdRel: 0.50) {
        factor = min(factor, 0.35)
      }
    }
    return max(0.25, min(1.0, factor))
  }

  private enum SpikeMode { case increase, decrease }

  private static func isSpike(
    series: [Double],
    recentDays: Int,
    baselineDays: Int,
    mode: SpikeMode,
    thresholdAbs: Double,
    thresholdRel: Double
  ) -> Bool {
    guard series.count >= recentDays + baselineDays else { return false }
    let recent = Array(series.suffix(recentDays))
    let baseline = Array(series.dropLast(recentDays).suffix(baselineDays))
    let r = mean(recent)
    let b = mean(baseline)
    guard b > 0 else { return false }
    let diff = r - b
    let rel = abs(diff) / b
    switch mode {
    case .increase: return diff >= thresholdAbs || rel >= thresholdRel
    case .decrease: return (-diff) >= thresholdAbs || rel >= thresholdRel
    }
  }

  private static func daysWithAnyData(metrics: [FitnessMetric: MetricSummary], now: Date) -> Int {
    _ = now
    let maxDays = metrics.values.map(\.daysPresent).max() ?? 0
    return min(max(0, maxDays), FitnessRatingConstants.fullConfidenceTargetDays)
  }

  private static func mean(_ xs: [Double]) -> Double {
    guard !xs.isEmpty else { return 0 }
    return xs.reduce(0, +) / Double(xs.count)
  }

  private static func standardDeviation(_ xs: [Double]) -> Double {
    guard xs.count >= 2 else { return 0 }
    let m = mean(xs)
    let v = xs.reduce(0) { $0 + pow($1 - m, 2) } / Double(xs.count - 1)
    return sqrt(max(0, v))
  }

  private static func coefficientOfVariation(_ xs: [Double]) -> Double {
    let m = mean(xs)
    guard m != 0 else { return 0 }
    return standardDeviation(xs) / abs(m)
  }

  private static func mapClamp(value: Double, inMin: Double, inMax: Double, outMin: Double, outMax: Double) -> Double {
    if value <= inMin { return outMin }
    if value >= inMax { return outMax }
    let t = (value - inMin) / (inMax - inMin)
    return outMin + t * (outMax - outMin)
  }
}

