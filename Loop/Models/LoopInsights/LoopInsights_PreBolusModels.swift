//
//  LoopInsights_PreBolusModels.swift
//  Loop
//
//  Pre-Bolus / Meal Timing Advisor models.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// MARK: - Meal Window

/// A time window during the day when the user typically eats a meal (derived from historical carb entries).
struct LoopInsightsMealWindow: Equatable {
    let centerHour: Int       // 0-23
    let startMinutes: Int     // minutes from midnight for window start
    let endMinutes: Int      // minutes from midnight for window end
    let mealCount: Int
    let inferredMealType: String  // "Breakfast", "Lunch", "Dinner", or "Snack"

    /// Check if the given date falls within this meal window.
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = hour * 60 + minute
        return totalMinutes >= startMinutes && totalMinutes <= endMinutes
    }
}

// MARK: - Pre-Bolus Context

/// All data assembled for the AI to generate pre-bolus advice.
struct LoopInsightsPreBolusContext {
    let currentGlucose: Double?           // mg/dL
    let glucoseTrend: String               // "rising", "flat", "falling"
    let insulinOnBoard: Double             // units
    let currentHour: Int
    let currentMinutes: Int
    let inferredMealType: String?
    let timeToPeakMinutes: Double?         // from food patterns for this meal type
    let lastMealDate: Date?
    let hoursSinceLastMeal: Double?
    let hasRecentCarbEntry: Bool           // carb entry in last 2 hours
    let mealWindowActive: Bool
}

// MARK: - Pre-Bolus Advice

/// AI-generated pre-bolus timing suggestion.
struct LoopInsightsPreBolusAdvice {
    let text: String
    let suggestedMinutesBeforeMeal: Int?   // optional parsed value
}
