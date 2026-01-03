import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum FitnessNorms {
  struct NormalParams: Equatable, Codable {
    var mean: Double
    var sd: Double
  }

  static func percentile(metric: FitnessMetric, value: Double, age: Int) -> Double {
    let cohort = AgeCohort.forAge(age)
    guard let params = paramsByMetricAndCohort[metric]?[cohort.label] else { return 0.5 }
    let p = normalCDF(value, mean: params.mean, sd: max(1e-6, params.sd))
    let clamped = min(1.0, max(0.0, p))
    if metric == .restingHeartRate || metric == .respiratoryRate {
      return 1.0 - clamped
    }
    return clamped
  }

  static let paramsByMetricAndCohort: [FitnessMetric: [String: NormalParams]] = [
    .steps: [
      "13–17": .init(mean: 9_500, sd: 3_200),
      "18–24": .init(mean: 9_000, sd: 3_000),
      "25–34": .init(mean: 8_500, sd: 2_900),
      "35–44": .init(mean: 8_000, sd: 2_800),
      "45–54": .init(mean: 7_500, sd: 2_700),
      "55–64": .init(mean: 7_000, sd: 2_600),
      "65+": .init(mean: 6_000, sd: 2_400),
    ],
    .sleepDuration: [
      "13–17": .init(mean: 8.2, sd: 1.0),
      "18–24": .init(mean: 7.6, sd: 0.9),
      "25–34": .init(mean: 7.3, sd: 0.9),
      "35–44": .init(mean: 7.2, sd: 0.9),
      "45–54": .init(mean: 7.1, sd: 0.9),
      "55–64": .init(mean: 7.0, sd: 0.9),
      "65+": .init(mean: 7.0, sd: 1.0),
    ],
    .restingHeartRate: [
      "13–17": .init(mean: 72, sd: 9),
      "18–24": .init(mean: 68, sd: 9),
      "25–34": .init(mean: 67, sd: 9),
      "35–44": .init(mean: 66, sd: 9),
      "45–54": .init(mean: 66, sd: 9),
      "55–64": .init(mean: 67, sd: 9),
      "65+": .init(mean: 68, sd: 10),
    ],
    .hrvSDNN: [
      "13–17": .init(mean: 55, sd: 22),
      "18–24": .init(mean: 52, sd: 20),
      "25–34": .init(mean: 48, sd: 19),
      "35–44": .init(mean: 45, sd: 18),
      "45–54": .init(mean: 42, sd: 17),
      "55–64": .init(mean: 40, sd: 16),
      "65+": .init(mean: 38, sd: 16),
    ],
    .vo2Max: [
      "13–17": .init(mean: 44, sd: 10),
      "18–24": .init(mean: 42, sd: 9.5),
      "25–34": .init(mean: 40, sd: 9),
      "35–44": .init(mean: 38, sd: 8.5),
      "45–54": .init(mean: 35.5, sd: 8),
      "55–64": .init(mean: 33, sd: 7.5),
      "65+": .init(mean: 30, sd: 7),
    ],
    .spO2: [
      "13–17": .init(mean: 0.975, sd: 0.01),
      "18–24": .init(mean: 0.975, sd: 0.01),
      "25–34": .init(mean: 0.974, sd: 0.01),
      "35–44": .init(mean: 0.974, sd: 0.01),
      "45–54": .init(mean: 0.973, sd: 0.01),
      "55–64": .init(mean: 0.972, sd: 0.012),
      "65+": .init(mean: 0.971, sd: 0.012),
    ],
    .respiratoryRate: [
      "13–17": .init(mean: 16.5, sd: 2.5),
      "18–24": .init(mean: 16.0, sd: 2.4),
      "25–34": .init(mean: 16.0, sd: 2.4),
      "35–44": .init(mean: 16.0, sd: 2.5),
      "45–54": .init(mean: 16.2, sd: 2.6),
      "55–64": .init(mean: 16.4, sd: 2.7),
      "65+": .init(mean: 16.6, sd: 2.8),
    ],
  ]

  private static func normalCDF(_ x: Double, mean: Double, sd: Double) -> Double {
    let z = (x - mean) / sd
    return 0.5 * (1.0 + erfApprox(z / sqrt(2.0)))
  }

  private static func erfApprox(_ x: Double) -> Double {
    #if canImport(Darwin)
    return Darwin.erf(x)
    #elseif canImport(Glibc)
    return Glibc.erf(x)
    #else
    let t = 1.0 / (1.0 + 0.5 * abs(x))
    let tau = t * exp(
      -x * x
        - 1.26551223
        + 1.00002368 * t
        + 0.37409196 * pow(t, 2)
        + 0.09678418 * pow(t, 3)
        - 0.18628806 * pow(t, 4)
        + 0.27886807 * pow(t, 5)
        - 1.13520398 * pow(t, 6)
        + 1.48851587 * pow(t, 7)
        - 0.82215223 * pow(t, 8)
        + 0.17087277 * pow(t, 9)
    )
    return x >= 0 ? 1.0 - tau : tau - 1.0
    #endif
  }
}

