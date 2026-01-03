import Foundation

#if canImport(HealthKit)
import HealthKit

/// Centralized, one-shot HealthKit authorization request for everything the app uses.
/// This avoids prompting tab-by-tab.
final class HealthKitAuthorizationService {
  private let store = HKHealthStore()

  func requestAllAuthorization() async throws {
    guard HKHealthStore.isHealthDataAvailable() else { return }

    var read: Set<HKObjectType> = []

    // Game scoring
    if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(t) }
    if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(t) }

    // Fitness rating (v2)
    if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .vo2Max) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { read.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { read.insert(t) }

    try await store.requestAuthorization(toShare: [], read: read)
  }
}

#else

final class HealthKitAuthorizationService {
  func requestAllAuthorization() async throws {}
}

#endif

