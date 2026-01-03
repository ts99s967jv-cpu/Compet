import XCTest
@testable import FitnessRatingEngine

final class FitnessRatingEngineTests: XCTestCase {
  func testNoData_isColdStartSafe_andEloDoesNotMove() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let inputs = FitnessRatingEngine.Inputs(
      age: 30,
      currentElo: 1500,
      metrics: [:],
      now: now
    )
    let out = FitnessRatingEngine.compute(inputs: inputs)

    XCTAssertEqual(out.expectedFPS, 0.5, accuracy: 1e-9)
    XCTAssertEqual(out.actualFPS, out.expectedFPS, accuracy: 1e-9)
    XCTAssertEqual(out.rating.elo, 1500, accuracy: 1e-9)
    XCTAssertEqual(out.rating.confidence, FitnessRatingConstants.confidenceMin, accuracy: 1e-9)
  }

  func testPartialData_updatesEloGradually() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let steps = FitnessRatingEngine.MetricSummary(
      value: 12_000, // above norm -> high percentile
      daysPresent: 14,
      windowDays: 28,
      dailyValues: Array(repeating: 12_000, count: 28)
    )

    let inputs = FitnessRatingEngine.Inputs(
      age: 30,
      currentElo: 1500,
      metrics: [.steps: steps],
      now: now
    )
    let out = FitnessRatingEngine.compute(inputs: inputs)

    XCTAssertGreaterThan(out.actualFPS, out.expectedFPS)
    XCTAssertGreaterThan(out.rating.elo, 1500)
    XCTAssertGreaterThan(out.rating.confidence, 0.14)
    XCTAssertLessThanOrEqual(out.rating.confidence, 1.0)
  }

  func testFullData_fpsIsConfidenceWeightedMean() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let window = 28

    let metrics: [FitnessMetric: FitnessRatingEngine.MetricSummary] = [
      .vo2Max: .init(value: 50, daysPresent: 7, windowDays: window, dailyValues: [50]),
      .hrvSDNN: .init(value: 70, daysPresent: window, windowDays: window, dailyValues: Array(repeating: 70, count: window)),
      .restingHeartRate: .init(value: 55, daysPresent: window, windowDays: window, dailyValues: Array(repeating: 55, count: window)),
      .steps: .init(value: 10_000, daysPresent: window, windowDays: window, dailyValues: Array(repeating: 10_000, count: window)),
      .sleepDuration: .init(value: 7.8, daysPresent: window, windowDays: window, dailyValues: Array(repeating: 7.8, count: window)),
      .respiratoryRate: .init(value: 14.5, daysPresent: window, windowDays: window, dailyValues: Array(repeating: 14.5, count: window)),
      .spO2: .init(value: 0.98, daysPresent: window, windowDays: window, dailyValues: Array(repeating: 0.98, count: window)),
    ]

    let inputs = FitnessRatingEngine.Inputs(age: 30, currentElo: 1500, metrics: metrics, now: now)
    let out = FitnessRatingEngine.compute(inputs: inputs)

    // Manual FPS recompute using the spec formula.
    var num: Double = 0
    var den: Double = 0
    for (m, w) in FitnessRatingConstants.weights {
      guard let s = metrics[m] else { continue }
      let c = FitnessRatingEngine.metricConfidence(daysPresent: s.daysPresent, windowDays: s.windowDays)
      guard c > 0 else { continue }
      let p = FitnessNorms.percentile(metric: m, value: s.value, age: 30)
      num += w * p * c
      den += w * c
    }
    let expectedFPS = num / den
    XCTAssertEqual(out.actualFPS, expectedFPS, accuracy: 1e-9)
    XCTAssertGreaterThan(out.kFactor, 0)
  }

  func testMigrationMapping_matchesSpec() throws {
    XCTAssertEqual(FitnessRatingMigration.v1ScoreToV2Elo(0), 1000, accuracy: 1e-9)
    XCTAssertEqual(FitnessRatingMigration.v1ScoreToV2Elo(3000), 2000, accuracy: 1e-9)
    XCTAssertEqual(FitnessRatingMigration.v1ScoreToV2Elo(1500), 1500, accuracy: 1e-9)
  }
}

