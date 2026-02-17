//
//  LoopDesignTokens.swift
//  Loop
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//
//  Centralized design tokens for consistent UI across the Loop app.
//

import SwiftUI
import UIKit

// MARK: - Semantic Colors (SwiftUI)

extension Color {
    /// LoopInsights feature accent (teal/cyan)
    static let loopInsightsAccent = Color("loopInsightsAccent")
    
    /// FoodFinder feature accent (purple/violet)
    static let foodFinderAccent = Color("foodFinderAccent")
    
    /// AI/Smart features accent (purple)
    static let aiAccent = Color("aiAccent")
    
    /// AutoPresets feature accent (green)
    static let autoPresetsAccent = Color("autoPresetsAccent")
    
    /// Surface color for cards (adapts to light/dark)
    static let cardSurface = Color(UIColor.secondarySystemBackground)
    
    /// Surface color for elevated sheets
    static let sheetSurface = Color(UIColor.tertiarySystemBackground)
}

// MARK: - Semantic Colors (UIKit)

extension UIColor {
    /// LoopInsights feature accent
    @nonobjc public static let loopInsightsAccent = UIColor(named: "loopInsightsAccent") ?? .systemTeal
    
    /// FoodFinder feature accent
    @nonobjc public static let foodFinderAccent = UIColor(named: "foodFinderAccent") ?? .systemPurple
    
    /// AI/Smart features accent
    @nonobjc public static let aiAccent = UIColor(named: "aiAccent") ?? .systemPurple
    
    /// AutoPresets feature accent
    @nonobjc public static let autoPresetsAccent = UIColor(named: "autoPresetsAccent") ?? .systemGreen
}

// MARK: - Typography

extension View {
    /// Loop title style - prominent section headers
    func loopTitleStyle() -> some View {
        font(.headline)
            .fontWeight(.semibold)
    }
    
    /// Loop body style - primary content
    func loopBodyStyle() -> some View {
        font(.body)
    }
    
    /// Loop caption style - secondary/descriptive text
    func loopCaptionStyle() -> some View {
        font(.subheadline)
            .foregroundColor(.secondary)
    }
}

// MARK: - Spacing

enum LoopSpacing {
    /// Extra small - 4pt
    static let xs: CGFloat = 4
    
    /// Small - 8pt
    static let sm: CGFloat = 8
    
    /// Medium - 12pt
    static let md: CGFloat = 12
    
    /// Large - 16pt
    static let lg: CGFloat = 16
    
    /// Extra large - 24pt
    static let xl: CGFloat = 24
    
    /// Section vertical spacing
    static let sectionVertical: CGFloat = 20
    
    /// Card internal padding
    static let cardPadding: CGFloat = 16
    
    /// Card corner radius
    static let cardCornerRadius: CGFloat = 12
}
