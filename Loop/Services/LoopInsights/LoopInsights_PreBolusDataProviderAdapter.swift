//
//  LoopInsights_PreBolusDataProviderAdapter.swift
//  Loop
//
//  Adapts Loop's stores to LoopInsightsPreBolusDataProvider for use when coordinator is not available
//  (e.g. CarbEntryView before user has opened LoopInsights).
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

/// Adapts GlucoseStoreProtocol, DoseStoreProtocol, and CarbStore to LoopInsightsPreBolusDataProvider.
final class LoopInsights_PreBolusDataProviderAdapter: LoopInsightsPreBolusDataProvider {

    private let glucoseStore: GlucoseStoreProtocol
    private let doseStore: DoseStoreProtocol
    private let carbStore: CarbStoreProtocol

    init(glucoseStore: GlucoseStoreProtocol, doseStore: DoseStoreProtocol, carbStore: CarbStoreProtocol) {
        self.glucoseStore = glucoseStore
        self.doseStore = doseStore
        self.carbStore = carbStore
    }

    func getGlucoseSamples(start: Date, end: Date) async throws -> [StoredGlucoseSample] {
        try await withCheckedThrowingContinuation { continuation in
            glucoseStore.getGlucoseSamples(start: start, end: end) { result in
                continuation.resume(with: result)
            }
        }
    }

    func getCarbEntries(start: Date, end: Date) async throws -> [StoredCarbEntry] {
        guard let store = carbStore as? CarbStore else {
            throw LoopInsightsError.insufficientData("CarbStore not available")
        }
        return try await withCheckedThrowingContinuation { continuation in
            store.getCarbEntries(start: start, end: end) { result in
                switch result {
                case .success(let entries):
                    continuation.resume(returning: entries)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getInsulinOnBoard(at date: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            doseStore.insulinOnBoard(at: date) { result in
                switch result {
                case .success(let insulinValue):
                    continuation.resume(returning: insulinValue.value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
