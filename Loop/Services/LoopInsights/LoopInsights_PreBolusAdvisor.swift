//
//  LoopInsights_PreBolusAdvisor.swift
//  Loop
//
//  Pre-Bolus / Meal Timing Advisor — meal window detection, context building, AI advice generation.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

// MARK: - Data Provider Protocol

/// Provides raw data needed for pre-bolus advice. Satisfied by LoopInsights_Coordinator or an adapter for standalone use.
protocol LoopInsightsPreBolusDataProvider: AnyObject {
    func getCarbEntries(start: Date, end: Date) async throws -> [StoredCarbEntry]
    func getGlucoseSamples(start: Date, end: Date) async throws -> [StoredGlucoseSample]
    func getInsulinOnBoard(at date: Date) async throws -> Double
}

// MARK: - Pre-Bolus Advisor

final class LoopInsights_PreBolusAdvisor {

    /// Minimum meals at an hour to consider it a meal window
    private static let minMealsForWindow = 2

    /// Window span: ±45 min around peak hour
    private static let windowHalfSpanMinutes = 45

    /// Don't prompt if user logged carbs in last 2 hours
    private static let recentCarbCutoffHours: Double = 2.0

    /// Don't suggest pre-bolus when glucose is below this (mg/dL)
    private static let lowGlucoseThreshold: Double = 70

    /// Caution on pre-bolus when IOB exceeds this (units)
    private static let highIOBThreshold: Double = 2.0

    // MARK: - Meal Window Detection

    /// Compute meal windows from hourly meal frequency (hour → meal count).
    static func computeMealWindows(from hourlyMealFrequency: [Int: Int]) -> [LoopInsightsMealWindow] {
        guard !hourlyMealFrequency.isEmpty else { return [] }

        let sorted = hourlyMealFrequency
            .filter { $0.value >= minMealsForWindow }
            .sorted { $0.value > $1.value }
            .prefix(4)  // Top 4 hours

        var windows: [LoopInsightsMealWindow] = []
        for (hour, count) in sorted {
            let startMinutes = max(0, hour * 60 - windowHalfSpanMinutes)
            let endMinutes = min(24 * 60 - 1, hour * 60 + windowHalfSpanMinutes)
            let mealType = inferredMealType(for: hour)
            windows.append(LoopInsightsMealWindow(
                centerHour: hour,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                mealCount: count,
                inferredMealType: mealType
            ))
        }
        return windows.sorted { $0.startMinutes < $1.startMinutes }
    }

    private static func inferredMealType(for hour: Int) -> String {
        switch hour {
        case 5..<10: return "Breakfast"
        case 10..<14: return "Lunch"
        case 14..<17: return "Afternoon snack"
        case 17..<22: return "Dinner"
        default: return "Snack"
        }
    }

    // MARK: - Context Building

    /// Build pre-bolus context from the data provider. Returns nil if insufficient data or guardrails block.
    static func buildContext(
        provider: LoopInsightsPreBolusDataProvider,
        at date: Date = Date()
    ) async throws -> LoopInsightsPreBolusContext? {
        let period = LoopInsightsAnalysisPeriod.fourteenDays
        let end = date
        let start = end.addingTimeInterval(-period.timeInterval)

        async let carbsTask = provider.getCarbEntries(start: start, end: end)
        async let glucoseTask = provider.getGlucoseSamples(start: start.addingTimeInterval(-6 * 3600), end: end)  // Last 6h for trend
        async let iobTask = provider.getInsulinOnBoard(at: date)

        let (carbEntries, glucoseSamples, iob) = try await (carbsTask, glucoseTask, iobTask)

        // Compute hourly meal frequency from carb entries
        var hourlyFrequency: [Int: Int] = [:]
        let calendar = Calendar.current
        for entry in carbEntries {
            let h = calendar.component(.hour, from: entry.startDate)
            hourlyFrequency[h, default: 0] += 1
        }
        let carbStats = LoopInsightsAggregatedStats.CarbStats(
            averageDailyCarbs: carbEntries.isEmpty ? 0 : carbEntries.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .gram()) } / Double(max(1, period.rawValue)),
            mealCount: carbEntries.count,
            averageCarbsPerMeal: carbEntries.isEmpty ? 0 : carbEntries.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .gram()) } / Double(carbEntries.count),
            hourlyMealFrequency: hourlyFrequency
        )

        let windows = computeMealWindows(from: carbStats.hourlyMealFrequency)
        let mealWindowActive = windows.contains { $0.contains(date) }

        let recentCutoff = date.addingTimeInterval(-Self.recentCarbCutoffHours * 3600)
        let hasRecentCarbEntry = carbEntries.contains { $0.startDate >= recentCutoff }

        let lastMealDate = carbEntries
            .filter { $0.startDate < date }
            .max(by: { $0.startDate < $1.startDate })
            .map { $0.startDate }
        let hoursSinceLastMeal = lastMealDate.map { date.timeIntervalSince($0) / 3600 }

        // Latest glucose and trend
        let sortedGlucose = glucoseSamples.sorted { $0.startDate < $1.startDate }
        let currentGlucose = sortedGlucose.last?.quantity.doubleValue(for: .milligramsPerDeciliter)

        let glucoseTrend: String
        if sortedGlucose.count >= 3 {
            let recent = sortedGlucose.suffix(3)
            let first = recent.first!.quantity.doubleValue(for: .milligramsPerDeciliter)
            let last = recent.last!.quantity.doubleValue(for: .milligramsPerDeciliter)
            let diff = last - first
            if diff > 5 { glucoseTrend = "rising" }
            else if diff < -5 { glucoseTrend = "falling" }
            else { glucoseTrend = "flat" }
        } else {
            glucoseTrend = "flat"
        }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        // Food patterns for time-to-peak (if we have food response analyzer data)
        let foodPatterns = LoopInsights_FoodResponseAnalyzer.analyzeFoodResponses(
            carbEntries: carbEntries,
            glucoseSamples: try await provider.getGlucoseSamples(start: start, end: end)
        )
        let inferredMealType = mealWindowActive ? windows.first(where: { $0.contains(date) })?.inferredMealType : nil
        let timeToPeakMinutes = foodPatterns.first?.timeToPeakMinutes  // Use first (highest impact) pattern as default

        return LoopInsightsPreBolusContext(
            currentGlucose: currentGlucose,
            glucoseTrend: glucoseTrend,
            insulinOnBoard: iob,
            currentHour: hour,
            currentMinutes: minute,
            inferredMealType: inferredMealType,
            timeToPeakMinutes: timeToPeakMinutes,
            lastMealDate: lastMealDate,
            hoursSinceLastMeal: hoursSinceLastMeal,
            hasRecentCarbEntry: hasRecentCarbEntry,
            mealWindowActive: mealWindowActive
        )
    }

    // MARK: - Guardrails

    /// Returns false if we should not suggest pre-bolus (e.g. low glucose, high IOB).
    static func shouldSuggestPreBolus(context: LoopInsightsPreBolusContext) -> Bool {
        if let glucose = context.currentGlucose, glucose < lowGlucoseThreshold {
            return false
        }
        if context.hasRecentCarbEntry {
            return false
        }
        return true
    }

    /// Returns a guardrail message if we should warn instead of suggest (e.g. high IOB).
    static func guardrailMessage(for context: LoopInsightsPreBolusContext) -> String? {
        if let glucose = context.currentGlucose, glucose < lowGlucoseThreshold {
            return NSLocalizedString("Glucose is below target. Wait until you're back in range before bolusing for a meal.", comment: "Pre-bolus advisor: low glucose")
        }
        if context.insulinOnBoard >= highIOBThreshold {
            return String(format: NSLocalizedString("You have %.1f U of active insulin. Consider reducing your bolus or waiting before eating.", comment: "Pre-bolus advisor: high IOB"), context.insulinOnBoard)
        }
        return nil
    }

    // MARK: - AI Advice Generation

    /// Generate pre-bolus advice from context via AI. Returns nil if no API key or guardrails block.
    static func generateAdvice(context: LoopInsightsPreBolusContext) async throws -> LoopInsightsPreBolusAdvice {
        if let msg = guardrailMessage(for: context) {
            return LoopInsightsPreBolusAdvice(text: msg, suggestedMinutesBeforeMeal: nil)
        }
        if !shouldSuggestPreBolus(context: context) {
            throw LoopInsightsError.insufficientData("Pre-bolus not recommended in current state")
        }

        let systemPrompt = """
        You are a pre-bolus timing advisor for someone with diabetes using an insulin pump.
        Given their current glucose, trend, insulin on board, time of day, and typical meal patterns,
        suggest when to pre-bolus (e.g. "15 min before eating"). Be concise — 1 or 2 sentences max.
        Do NOT suggest specific insulin amounts — only timing. If their glucose is rising and they're
        in a typical meal window, recommend pre-bolusing soon. If unsure, err on the side of caution.
        """

        var userPrompt = """
        Current time: \(context.currentHour):\(String(format: "%02d", context.currentMinutes))
        Glucose: \(context.currentGlucose.map { String(format: "%.0f", $0) + " mg/dL" } ?? "unknown")
        Glucose trend: \(context.glucoseTrend)
        Insulin on board: \(String(format: "%.1f", context.insulinOnBoard)) U
        """
        if let mealType = context.inferredMealType {
            userPrompt += "\nInferred meal: \(mealType)"
        }
        if let ttp = context.timeToPeakMinutes {
            userPrompt += "\nTypical time to peak for similar meals: \(String(format: "%.0f", ttp)) min"
        }
        if let hours = context.hoursSinceLastMeal {
            userPrompt += "\nHours since last meal: \(String(format: "%.1f", hours))"
        }
        userPrompt += "\n\nWhen should they pre-bolus? One or two sentences."

        let response = try await LoopInsights_AIServiceAdapter.shared.sendPrompt(systemPrompt, userPrompt: userPrompt)
        return LoopInsightsPreBolusAdvice(text: response.trimmingCharacters(in: .whitespacesAndNewlines), suggestedMinutesBeforeMeal: nil)
    }

    /// Build context and generate advice in one call. Returns nil if insufficient data or disabled.
    static func buildContextAndGenerateAdvice(
        provider: LoopInsightsPreBolusDataProvider
    ) async throws -> LoopInsightsPreBolusAdvice? {
        guard LoopInsights_FeatureFlags.isEnabled else { return nil }
        guard LoopInsights_FeatureFlags.preBolusAdvisorEnabled else { return nil }
        guard LoopInsights_SecureStorage.hasAPIKey else { return nil }

        guard let context = try await buildContext(provider: provider) else {
            return nil
        }

        guard context.mealWindowActive else {
            return nil
        }

        return try await generateAdvice(context: context)
    }

    /// Build context and generate advice for in-flow use (e.g. CarbEntryView). Does not require meal window.
    static func buildContextAndGenerateAdviceInFlow(
        provider: LoopInsightsPreBolusDataProvider
    ) async throws -> LoopInsightsPreBolusAdvice? {
        guard LoopInsights_FeatureFlags.isEnabled else { return nil }
        guard LoopInsights_FeatureFlags.preBolusAdvisorEnabled else { return nil }
        guard LoopInsights_SecureStorage.hasAPIKey else { return nil }

        guard let context = try await buildContext(provider: provider) else {
            return nil
        }

        return try await generateAdvice(context: context)
    }
}
