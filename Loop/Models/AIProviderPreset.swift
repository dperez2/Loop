//
//  AIProviderPreset.swift
//  Loop
//
//  Predefined AI provider configurations. Select a provider to auto-fill base URL,
//  default model, and API key signup link — user only needs to paste their API key.
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

/// Predefined AI provider presets for one-tap configuration.
/// Selecting a preset auto-fills base URL and default model so users only need to paste their API key.
enum AIProviderPreset: String, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case gemini
    case grok
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI (GPT)"
        case .anthropic: return "Anthropic (Claude)"
        case .gemini: return "Google (Gemini)"
        case .grok: return "xAI (Grok)"
        case .custom: return "Custom"
        }
    }

    /// Base URL for the API. Empty for custom.
    var baseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .grok: return "https://api.x.ai/v1"
        case .custom: return ""
        }
    }

    /// Default model name for the provider.
    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .gemini: return "gemini-2.0-flash"
        case .grok: return "grok-2"
        case .custom: return ""
        }
    }

    /// URL where users can obtain an API key. Empty for custom.
    var apiKeySignupURL: String {
        switch self {
        case .openAI: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .grok: return "https://console.x.ai"
        case .custom: return ""
        }
    }

    /// Accent color for UI (provider branding).
    var accentColor: Color {
        switch self {
        case .openAI: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        case .grok: return .red
        case .custom: return .secondary
        }
    }

    /// Detect which preset (if any) matches the given base URL.
    static func detect(from baseURL: String) -> AIProviderPreset {
        let lower = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return .custom }
        if lower.contains("api.openai.com") { return .openAI }
        if lower.contains("anthropic.com") { return .anthropic }
        if lower.contains("googleapis.com") || lower.contains("generativelanguage") { return .gemini }
        if lower.contains("api.x.ai") { return .grok }
        return .custom
    }
}
