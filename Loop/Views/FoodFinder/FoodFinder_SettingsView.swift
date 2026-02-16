//
//  FoodFinder_SettingsView.swift
//  Loop
//
//  FoodFinder — Settings UI for configuring AI food analysis providers.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// Settings view for configuring AI food analysis.
/// Completely AI-agnostic — the user enters their own endpoint, key, and model.
struct AISettingsView: View {
    @Environment(\.openURL) var openURL

    // Feature toggles
    @AppStorage("com.loopkit.Loop.foodSearchEnabled") private var foodSearchEnabled: Bool = false
    @AppStorage("com.loopkit.Loop.advancedDosingRecommendationsEnabled") private var advancedDosingRecommendationsEnabled: Bool = false
    @AppStorage("com.loopkit.Loop.analysisHistoryRetentionDays") private var retentionDays: Int = 7

    // API keys (Keychain-backed) — USDA only; AI key is in Settings > AI Provider
    @State private var usdaAPIKey: String = ""

    // UI state
    @State private var showUSDAKey: Bool = false

    var body: some View {
        Form {
            featureToggleSection
            if foodSearchEnabled {
                usdaSection
                aiProviderLinkSection
            }
        }
        .navigationTitle("FoodFinder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            usdaAPIKey = FoodFinder_SecureStorage.loadUSDAKey() ?? ""
            SharedAI_Config.syncToFeatures()
        }
    }
}

// MARK: - Sections

extension AISettingsView {

    // MARK: Feature Toggle

    private var featureToggleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundColor(Color(red: 107/255, green: 47/255, blue: 160/255))
                    Text("FOODFINDER")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                Toggle("Enable FoodFinder", isOn: $foodSearchEnabled)
                Text("Enable this to show FoodFinder in the carb entry screen. Requires Internet connection. When disabled, the feature is hidden but settings are preserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if foodSearchEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "cross.fill")
                                .foregroundColor(.red)
                            Text("MEDICAL DISCLAIMER")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .lineLimit(1)
                        }
                        Text("AI nutritional estimates are approximations only. Verify information before dosing; this is not medical advice.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Analysis History")
                        Picker("", selection: $retentionDays) {
                            Text("Last 24 hours").tag(1)
                            Text("Last 7 days").tag(7)
                            Text("Last 14 days").tag(14)
                            Text("Last 30 days").tag(30)
                        }
                        .pickerStyle(.menu)
                    }
                    Text("How long to keep AI-analyzed foods available for quick re-entry.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider()
                    Toggle("Advanced Dosing Insights", isOn: $advancedDosingRecommendationsEnabled)
                    Text("Enable advanced dosing advice including Fat/Protein Units (FPUs) calculations. Prolongs analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: AI Provider Link

    private var aiProviderLinkSection: some View {
        Section {
            NavigationLink(destination: SharedAI_SettingsView()) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .frame(width: 28, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Provider")
                            .font(.body.weight(.medium))
                        Text("Configure API key for food analysis. Shared with LoopInsights.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: USDA Database

    private var usdaSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf").foregroundColor(.green)
                    Text("USDA DATABASE (TEXT SEARCH)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                HStack(spacing: 8) {
                    Group {
                        if showUSDAKey {
                            TextField("Enter your USDA API key (optional)", text: $usdaAPIKey)
                        } else {
                            SecureField("Enter your USDA API key (optional)", text: $usdaAPIKey)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: usdaAPIKey) { newValue in
                        saveUSDAKey(newValue)
                    }
                    Button(action: { showUSDAKey.toggle() }) {
                        Image(systemName: showUSDAKey ? "eye.slash" : "eye").foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { if let url = URL(string: "https://fdc.nal.usda.gov/api-guide") { openURL(url) } }) {
                    HStack { Image(systemName: "info.circle"); Text("How to get a key") }
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text("How to obtain a USDA API key:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("1. Open the USDA FoodData Central API Guide. 2. Sign in or create an account. 3. Request a new API key. 4. Copy and paste it here. The key activates immediately.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why add a key?")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Without your own key, searches use a public DEMO_KEY that is heavily rate-limited and often returns 429 errors. Adding your free personal key avoids this.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

}

// MARK: - Actions

extension AISettingsView {

    private func saveUSDAKey(_ key: String) {
        if key.isEmpty {
            try? FoodFinder_SecureStorage.deleteUSDAKey()
        } else {
            try? FoodFinder_SecureStorage.saveUSDAKey(key)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AISettingsView()
        }
    }
}
#endif
