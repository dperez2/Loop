//
//  LoopInsights_SettingsView.swift
//  Loop
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in February 2026.
//  Copyright (c) 2025-2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Combine
import LoopKit

/// LoopInsights settings and configuration view.
/// Accessible from Loop's main SettingsView via NavigationLink.
struct LoopInsights_SettingsView: View {

    @Environment(\.openURL) var openURL

    /// Real data store references passed from Loop's SettingsView (type-erased).
    /// When nil, falls back to test data (simulator / preview).
    var dataStoresProvider: (() -> Any?)?

    @State private var isEnabled = LoopInsights_FeatureFlags.isEnabled
    @State private var selectedPeriod = LoopInsights_FeatureFlags.analysisPeriod
    @State private var selectedApplyMode = LoopInsights_FeatureFlags.applyMode
    @State private var selectedPersonality = LoopInsights_FeatureFlags.aiPersonality

    // Data
    @State private var showingClearHistory = false

    // Biometrics
    @State private var biometricsEnabled = LoopInsights_FeatureFlags.biometricsEnabled
    @StateObject private var healthKitManager = LoopInsights_HealthKitManager()
    @State private var isRequestingBiometricAuth = false

    // Phase 5 flags
    @State private var circadianEnabled = LoopInsights_FeatureFlags.circadianEnabled
    @State private var foodResponseEnabled = LoopInsights_FeatureFlags.foodResponseEnabled
    @State private var caffeineTrackingEnabled = LoopInsights_FeatureFlags.caffeineTrackingEnabled
    @State private var nightscoutImportEnabled = LoopInsights_FeatureFlags.nightscoutImportEnabled
    @State private var agpChartEnabled = LoopInsights_FeatureFlags.agpChartEnabled

    // Nightscout
    @State private var nightscoutConfig = LoopInsightsNightscoutConfig.load()
    @State private var isTestingNightscout = false
    @State private var nightscoutTestResult: TestResult?

    // Developer mode unlock
    @State private var developerTapCount = 0
    @State private var showDeveloperUnlocked = false

    // Test data (developer mode)
    @State private var useTestData = LoopInsights_FeatureFlags.useTestData
    @State private var testDataProvider: LoopInsights_TestDataProvider?
    @State private var showTestDashboard = false

    private enum TestResult {
        case success
        case warning(String)
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    init(dataStoresProvider: (() -> Any?)? = nil) {
        self.dataStoresProvider = dataStoresProvider
    }

    var body: some View {
        Form {
            featureToggleSection
            if isEnabled {
                analysisOptionsSection
                biometricsSection
                phase5FeaturesSection
                if nightscoutImportEnabled {
                    nightscoutSection
                }
                personalitySection
                backgroundMonitoringSection
                dataSection
                if LoopInsights_FeatureFlags.developerModeEnabled {
                    developerSection
                }
            }
        }
        .navigationTitle(NSLocalizedString("LoopInsights Settings", comment: "LoopInsights settings title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            SharedAI_Config.syncToFeatures()
            // Re-sync @State from persisted values on every appearance
            isEnabled = LoopInsights_FeatureFlags.isEnabled
            selectedPeriod = LoopInsights_FeatureFlags.analysisPeriod
            selectedApplyMode = LoopInsights_FeatureFlags.applyMode
            selectedPersonality = LoopInsights_FeatureFlags.aiPersonality
            useTestData = LoopInsights_FeatureFlags.useTestData
            biometricsEnabled = LoopInsights_FeatureFlags.biometricsEnabled
            circadianEnabled = LoopInsights_FeatureFlags.circadianEnabled
            foodResponseEnabled = LoopInsights_FeatureFlags.foodResponseEnabled
            caffeineTrackingEnabled = LoopInsights_FeatureFlags.caffeineTrackingEnabled
            nightscoutImportEnabled = LoopInsights_FeatureFlags.nightscoutImportEnabled
            agpChartEnabled = LoopInsights_FeatureFlags.agpChartEnabled
            nightscoutConfig = LoopInsightsNightscoutConfig.load()
        }
        .alert(
            NSLocalizedString("Clear History", comment: "LoopInsights clear history alert title"),
            isPresented: $showingClearHistory
        ) {
            Button(NSLocalizedString("Clear All", comment: "LoopInsights clear all button"), role: .destructive) {
                LoopInsights_SuggestionStore.shared.clearAllHistory()
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("This will permanently delete all suggestion history. This cannot be undone.", comment: "LoopInsights clear history warning"))
        }
        .alert(
            NSLocalizedString("Developer Mode", comment: "LoopInsights developer mode alert title"),
            isPresented: $showDeveloperUnlocked
        ) {
            Button(NSLocalizedString("OK", comment: "OK button")) {}
        } message: {
            Text(NSLocalizedString("Developer mode has been enabled. You now have access to test data fixtures and auto-apply mode.", comment: "LoopInsights developer mode unlocked message"))
        }
        .sheet(isPresented: $showTestDashboard) {
            NavigationView {
                LoopInsights_TestDashboardWrapper(dataStoresProvider: dataStoresProvider)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(NSLocalizedString("Done", comment: "Done button")) {
                                showTestDashboard = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Feature Toggle

    private var featureToggleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.loopInsightsAccent)
                    Text("LOOPINSIGHTS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .onLongPressGesture(minimumDuration: 1) {
                    developerTapCount += 1
                    if developerTapCount >= LoopInsights_FeatureFlags.developerUnlockThreshold {
                        LoopInsights_FeatureFlags.developerModeEnabled = true
                        developerTapCount = 0
                        showDeveloperUnlocked = true
                    }
                }

                Toggle(NSLocalizedString("Enable LoopInsights", comment: "LoopInsights enable toggle"), isOn: $isEnabled)
                    .onChange(of: isEnabled) { newValue in
                        LoopInsights_FeatureFlags.isEnabled = newValue
                    }

                Text(NSLocalizedString("Enable AI-powered therapy settings analysis and suggestions. When disabled, the feature is hidden but settings are preserved.", comment: "LoopInsights feature toggle description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "cross.fill")
                                .foregroundColor(.red)
                            Text(NSLocalizedString("MEDICAL DISCLAIMER", comment: "LoopInsights medical disclaimer header"))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .lineLimit(1)
                        }
                        Text(NSLocalizedString("AI therapy suggestions are advisory only. You are responsible for reviewing all changes. Consult your healthcare provider for significant therapy adjustments.", comment: "LoopInsights medical disclaimer"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: { showTestDashboard = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title3)
                            Text(NSLocalizedString("Open Dashboard", comment: "LoopInsights open dashboard button"))
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
    }

    // MARK: - Analysis Options (Apply Mode + Period)

    private var analysisOptionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("ANALYSIS OPTIONS", comment: "LoopInsights analysis options header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                // Lookback period slider
                VStack(spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Lookback Period", comment: "LoopInsights period picker"))
                            .font(.subheadline)
                        Spacer()
                        Text(selectedPeriod.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }

                    let cases = LoopInsightsAnalysisPeriod.allCases
                    let currentIndex = Double(cases.firstIndex(of: selectedPeriod) ?? 0)
                    Slider(
                        value: Binding(
                            get: { currentIndex },
                            set: { newValue in
                                let index = Int(newValue.rounded())
                                if index >= 0 && index < cases.count {
                                    selectedPeriod = cases[index]
                                }
                            }
                        ),
                        in: 0...Double(cases.count - 1),
                        step: 1
                    )
                    HStack {
                        Text(cases.first?.displayName ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cases.last?.displayName ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: selectedPeriod) { newValue in
                    LoopInsights_FeatureFlags.analysisPeriod = newValue
                }

                Text(NSLocalizedString("Rolling lookback period for automated AI-based suggestions - how far back do you want LoopInsights to look when analyzing your glucose, insulin, and carb data?", comment: "LoopInsights analysis period description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Apply mode picker
                let availableModes = LoopInsights_FeatureFlags.developerModeEnabled
                    ? LoopInsightsApplyMode.allCases
                    : LoopInsightsApplyMode.publicModes

                HStack {
                    Text(NSLocalizedString("When applying suggestions", comment: "LoopInsights apply mode picker"))
                    Spacer()
                    Menu {
                        ForEach(availableModes) { mode in
                            Button(action: {
                                selectedApplyMode = mode
                                LoopInsights_FeatureFlags.applyMode = mode
                            }) {
                                if mode == selectedApplyMode {
                                    Label(mode == .autoApply ? "\(mode.displayName) \u{26A0}\u{FE0F}" : mode.displayName, systemImage: "checkmark")
                                } else {
                                    Text(mode == .autoApply ? "\(mode.displayName) \u{26A0}\u{FE0F}" : mode.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedApplyMode.displayName)
                                .foregroundColor(selectedApplyMode == .autoApply ? .orange : .accentColor)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(selectedApplyMode == .autoApply ? .orange : .accentColor)
                        }
                    }
                }

                Text(selectedApplyMode.description)
                    .font(.caption)
                    .foregroundColor(selectedApplyMode == .autoApply ? .orange : .secondary)
            }
        }
    }

    // MARK: - Biometrics

    private var biometricsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("BIOMETRICS", comment: "LoopInsights biometrics header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                Toggle(NSLocalizedString("Include Biometric Data", comment: "LoopInsights biometrics toggle"), isOn: $biometricsEnabled)
                    .onChange(of: biometricsEnabled) { newValue in
                        LoopInsights_FeatureFlags.biometricsEnabled = newValue
                        if newValue && !healthKitManager.authorizationRequested {
                            requestBiometricAuthorization()
                        }
                    }

                Text(NSLocalizedString("When enabled, LoopInsights includes heart rate, HRV, steps, sleep, active energy, and weight data in AI analysis. This helps the AI correlate lifestyle factors with glucose patterns.", comment: "LoopInsights biometrics description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if biometricsEnabled {
                    if !LoopInsights_HealthKitManager.isHealthDataAvailable {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(NSLocalizedString("HealthKit is not available on this device.", comment: "LoopInsights HealthKit not available"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        // Authorization button (show when not yet requested)
                        if !healthKitManager.authorizationRequested {
                            Button(action: requestBiometricAuthorization) {
                                HStack(spacing: 6) {
                                    if isRequestingBiometricAuth {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "heart.circle")
                                    }
                                    Text(NSLocalizedString("Authorize HealthKit Access", comment: "LoopInsights authorize HealthKit button"))
                                }
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.pink)
                                .cornerRadius(10)
                            }
                            .disabled(isRequestingBiometricAuth)
                            .buttonStyle(.plain)
                        } else {
                            // Authorization sheet was shown — we can't see read permission status
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("HealthKit permissions configured", comment: "LoopInsights HealthKit permissions configured"))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }

                        // Biometric types list (two columns)
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                biometricTypeLabel("Heart Rate", icon: "heart.fill")
                                biometricTypeLabel("HRV", icon: "waveform.path.ecg")
                                biometricTypeLabel("Steps", icon: "figure.walk")
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                biometricTypeLabel("Sleep", icon: "bed.double.fill")
                                biometricTypeLabel("Energy", icon: "flame.fill")
                                biometricTypeLabel("Weight", icon: "scalemass.fill")
                            }
                        }

                        Text(NSLocalizedString("Biometric data is read-only and never leaves your device except as part of AI analysis prompts. Manage permissions in Settings > Health > Loop.", comment: "LoopInsights biometrics privacy note"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func biometricTypeLabel(_ name: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.pink)
                .font(.caption)
                .frame(width: 16)
            Text(name)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }

    private func requestBiometricAuthorization() {
        isRequestingBiometricAuth = true
        Task {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                LoopInsights_FeatureFlags.log.error("HealthKit authorization error: \(error)")
            }
            await MainActor.run {
                isRequestingBiometricAuth = false
            }
        }
    }

    // MARK: - AI Personality

    private var personalitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "theatermasks")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("AI PERSONALITY", comment: "LoopInsights AI personality header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                Picker(NSLocalizedString("Response Style", comment: "LoopInsights personality picker label"), selection: $selectedPersonality) {
                    ForEach(LoopInsightsAIPersonality.allCases) { personality in
                        Text(personality.displayName).tag(personality)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPersonality) { newValue in
                    LoopInsights_FeatureFlags.aiPersonality = newValue
                }

                Text(selectedPersonality.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Background Monitoring

    private var backgroundMonitoringSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("BACKGROUND MONITORING", comment: "LoopInsights background monitoring header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                NavigationLink {
                    LoopInsights_MonitorSettingsView()
                } label: {
                    HStack {
                        Text(NSLocalizedString("Background Monitoring", comment: "LoopInsights background monitoring row"))
                        Spacer()
                        Text(LoopInsights_FeatureFlags.backgroundMonitorEnabled
                            ? LoopInsights_FeatureFlags.monitorFrequency.displayName
                            : NSLocalizedString("Off", comment: "LoopInsights monitoring off"))
                            .foregroundColor(.secondary)
                    }
                }

                Text(NSLocalizedString("LoopInsights can continuously monitor your data and proactively notify you when it detects a setting change opportunity.", comment: "LoopInsights background monitoring description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("SUGGESTION HISTORY", comment: "LoopInsights history header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                HStack {
                    Text(NSLocalizedString("Stored Suggestions", comment: "LoopInsights stored suggestions label"))
                    Spacer()
                    Text("\(LoopInsights_SuggestionStore.shared.allRecords.count)")
                        .foregroundColor(.secondary)
                    Button(role: .destructive, action: { showingClearHistory = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Developer Section (Hidden)

    private var developerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("DEVELOPER", comment: "LoopInsights developer section header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .textCase(.uppercase)
                }

                HStack {
                    Text(NSLocalizedString("Developer Mode", comment: "LoopInsights developer mode label"))
                    Spacer()
                    Text(NSLocalizedString("Active", comment: "LoopInsights developer mode active"))
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }

                if selectedApplyMode == .autoApply {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(NSLocalizedString("Auto-Apply is enabled. High-confidence suggestions will be applied automatically.", comment: "LoopInsights auto-apply warning"))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Test Data Toggle
                Toggle(NSLocalizedString("Use Test Data Fixtures", comment: "LoopInsights test data toggle"), isOn: $useTestData)
                    .onChange(of: useTestData) { newValue in
                        LoopInsights_FeatureFlags.useTestData = newValue
                        if newValue {
                            testDataProvider = LoopInsights_TestDataProvider()
                        } else {
                            testDataProvider = nil
                        }
                    }

                Text(NSLocalizedString("Load JSON fixtures from Documents/LoopInsights/ instead of real Loop data. Use pull_tidepool_data.py to generate fixtures from your Tidepool account.", comment: "LoopInsights test data description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Test data status
                if useTestData {
                    testDataStatusView
                }

                Button(action: {
                    LoopInsights_FeatureFlags.developerModeEnabled = false
                    LoopInsights_FeatureFlags.applyMode = .manual
                    selectedApplyMode = .manual
                    useTestData = false
                    LoopInsights_FeatureFlags.useTestData = false
                    testDataProvider = nil
                }) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text(NSLocalizedString("Disable Developer Mode", comment: "LoopInsights disable developer button"))
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Test Data Status

    private var testDataStatusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let provider = testDataProvider {
                if provider.hasTestData {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(NSLocalizedString("Fixtures loaded", comment: "LoopInsights fixtures loaded"))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Text(provider.dataSummary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let range = provider.dateRange {
                        let formatter = DateFormatter()
                        let _ = formatter.dateStyle = .short
                        Text("\(formatter.string(from: range.start)) — \(formatter.string(from: range.end))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(NSLocalizedString("No fixtures found", comment: "LoopInsights no fixtures"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Text(NSLocalizedString("Place fixture files in Documents/LoopInsights/ or rebuild with bundled test data.", comment: "LoopInsights no fixtures hint"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Documents path: \(LoopInsights_TestDataProvider.documentsDirectory.path)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .onAppear {
            if useTestData && testDataProvider == nil {
                testDataProvider = LoopInsights_TestDataProvider()
            }
        }
    }


    // MARK: - Phase 5 Features

    private var phase5FeaturesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("ADVANCED FEATURES", comment: "LoopInsights Phase 5 features header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                Toggle(NSLocalizedString("Circadian Analysis", comment: "LoopInsights circadian toggle"), isOn: $circadianEnabled)
                    .onChange(of: circadianEnabled) { newValue in
                        LoopInsights_FeatureFlags.circadianEnabled = newValue
                    }
                Text(NSLocalizedString("Enables circadian glucose profiling, dawn phenomenon detection, negative basal awareness, and HRV-based stress scoring. Enriches AI analysis with sleep/wake patterns.", comment: "LoopInsights circadian description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Toggle(NSLocalizedString("Food Response Analysis", comment: "LoopInsights food response toggle"), isOn: $foodResponseEnabled)
                    .onChange(of: foodResponseEnabled) { newValue in
                        LoopInsights_FeatureFlags.foodResponseEnabled = newValue
                    }
                Text(NSLocalizedString("Analyzes glucose responses by food type. Enables Meal Insights view with meal debrief cards and pre-meal AI advisor.", comment: "LoopInsights food response description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Toggle(NSLocalizedString("Caffeine Tracking", comment: "LoopInsights caffeine toggle"), isOn: $caffeineTrackingEnabled)
                    .onChange(of: caffeineTrackingEnabled) { newValue in
                        LoopInsights_FeatureFlags.caffeineTrackingEnabled = newValue
                    }
                Text(NSLocalizedString("Log caffeine intake to help the AI correlate caffeine with glucose patterns. Uses a 5.7-hour half-life decay model.", comment: "LoopInsights caffeine description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Toggle(NSLocalizedString("AGP Chart", comment: "LoopInsights AGP toggle"), isOn: $agpChartEnabled)
                    .onChange(of: agpChartEnabled) { newValue in
                        LoopInsights_FeatureFlags.agpChartEnabled = newValue
                    }
                Text(NSLocalizedString("Show Ambulatory Glucose Profile chart on the dashboard with percentile bands (P10/P25/P50/P75/P90) over 24 hours.", comment: "LoopInsights AGP description"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Toggle(NSLocalizedString("Nightscout Import", comment: "LoopInsights nightscout toggle"), isOn: $nightscoutImportEnabled)
                    .onChange(of: nightscoutImportEnabled) { newValue in
                        LoopInsights_FeatureFlags.nightscoutImportEnabled = newValue
                    }
                Text(NSLocalizedString("Import glucose and treatment data from a Nightscout server as a supplemental data source.", comment: "LoopInsights nightscout description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Nightscout Configuration

    private var nightscoutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("NIGHTSCOUT", comment: "LoopInsights Nightscout header"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Site URL", comment: "LoopInsights Nightscout URL label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("https://your-site.herokuapp.com", text: $nightscoutConfig.siteURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .onChange(of: nightscoutConfig.siteURL) { _ in
                            nightscoutConfig.isConnected = false
                            nightscoutTestResult = nil
                            nightscoutConfig.save()
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("API Secret", comment: "LoopInsights Nightscout API secret label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField(NSLocalizedString("Your API secret", comment: "LoopInsights Nightscout secret placeholder"), text: $nightscoutConfig.apiSecret)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: nightscoutConfig.apiSecret) { _ in
                            nightscoutConfig.isConnected = false
                            nightscoutTestResult = nil
                            nightscoutConfig.save()
                        }
                }

                // Test Connection
                Button(action: testNightscoutConnection) {
                    HStack(spacing: 6) {
                        if isTestingNightscout {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .tint(.black)
                            Text(NSLocalizedString("Testing...", comment: "LoopInsights testing nightscout"))
                        } else {
                            Image(systemName: "checkmark.shield")
                            Text(NSLocalizedString("Test Connection", comment: "LoopInsights test nightscout button"))
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .disabled(isTestingNightscout || nightscoutConfig.siteURL.isEmpty)
                .opacity((isTestingNightscout || nightscoutConfig.siteURL.isEmpty) ? 0.5 : 1.0)
                .buttonStyle(.plain)

                if let result = nightscoutTestResult {
                    switch result {
                    case .success:
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(NSLocalizedString("Connected to Nightscout", comment: "LoopInsights nightscout connected"))
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    case .failure(let message):
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    case .warning(let message):
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Text(NSLocalizedString("Nightscout data is used as supplemental context for AI analysis. Your existing Loop data stores remain the primary source.", comment: "LoopInsights nightscout note"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func testNightscoutConnection() {
        isTestingNightscout = true
        nightscoutTestResult = nil

        Task {
            do {
                let importer = LoopInsights_NightscoutImporter(config: nightscoutConfig)
                let success = try await importer.testConnection()
                await MainActor.run {
                    nightscoutConfig.isConnected = success
                    nightscoutConfig.save()
                    nightscoutTestResult = success ? .success : .failure("Unknown error")
                    isTestingNightscout = false
                }
            } catch {
                await MainActor.run {
                    nightscoutConfig.isConnected = false
                    nightscoutConfig.save()
                    nightscoutTestResult = .failure(error.localizedDescription)
                    isTestingNightscout = false
                }
            }
        }
    }

}

// MARK: - Dashboard Wrapper

/// Lightweight container that owns the ViewModel and defers heavy creation to
/// onAppear. Also forwards the ViewModel's objectWillChange to its own publisher
/// so the wrapper view re-renders when any ViewModel @Published property changes.
/// This allows DashboardView to use a plain `var` instead of @ObservedObject,
/// avoiding a silent SwiftUI crash during sheet presentation rendering.
private class LoopInsights_DashboardContainer: ObservableObject {
    @Published var viewModel: LoopInsights_DashboardViewModel?
    /// Increments on every ViewModel objectWillChange, forcing SwiftUI to
    /// re-evaluate DashboardView's body (since the reference itself doesn't change).
    @Published var renderTrigger: Int = 0
    private var vmCancellable: AnyCancellable?

    func initializeIfNeeded(dataStoresProvider: (() -> Any?)? = nil) {
        guard viewModel == nil else { return }

        let coordinator: LoopInsights_Coordinator

        // Developer mode: test data takes priority
        if let testCoordinator = LoopInsights_Coordinator.withTestDataIfAvailable() {
            coordinator = testCoordinator
        }
        // Real data stores from Loop (cast from type-erased tuple)
        else if let any = dataStoresProvider?(),
                let stores = any as? (GlucoseStoreProtocol, DoseStoreProtocol, CarbStoreProtocol, LatestStoredSettingsProvider, LoopInsightsSettingsWriter) {
            coordinator = LoopInsights_Coordinator(
                glucoseStore: stores.0,
                doseStore: stores.1,
                carbStore: stores.2,
                settingsProvider: stores.3,
                settingsWriter: stores.4
            )
        }
        // Fallback: test data provider (simulator with no real stores)
        else {
            let provider = LoopInsights_TestDataProvider()
            coordinator = LoopInsights_Coordinator(testDataProvider: provider)
        }

        // Start background monitoring if enabled
        coordinator.startBackgroundMonitoring()

        let vm = LoopInsights_DashboardViewModel(coordinator: coordinator)

        // Forward ViewModel's objectWillChange → increment renderTrigger
        // so SwiftUI sees a value change and re-evaluates DashboardView
        vmCancellable = vm.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.renderTrigger += 1
            }
        }

        // Defer @Published assignment to next run loop to avoid
        // objectWillChange during SwiftUI's view update cycle
        DispatchQueue.main.async { [weak self] in
            self?.viewModel = vm
        }
    }
}

/// Wrapper view that owns the Container via @StateObject and presents
/// the DashboardView once the ViewModel is ready.
private struct LoopInsights_TestDashboardWrapper: View {
    @StateObject private var container = LoopInsights_DashboardContainer()
    var dataStoresProvider: (() -> Any?)?

    var body: some View {
        Group {
            if let vm = container.viewModel {
                LoopInsights_DashboardView(
                    viewModel: vm,
                    renderTrigger: container.renderTrigger
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(NSLocalizedString("Loading data...", comment: "LoopInsights loading data"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            container.initializeIfNeeded(dataStoresProvider: dataStoresProvider)
        }
    }
}
