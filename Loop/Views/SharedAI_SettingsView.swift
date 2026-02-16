//
//  SharedAI_SettingsView.swift
//  Loop
//
//  Central AI provider configuration for the whole app.
//  Used by FoodFinder and LoopInsights — configure once, use everywhere.
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// Central settings view for AI provider configuration.
/// Provider dropdown + API key. Base URL and Model hidden when a preset is selected.
struct SharedAI_SettingsView: View {
    @Environment(\.openURL) var openURL

    @AppStorage("com.loopkit.Loop.sharedAIBaseURL") private var baseURL: String = ""
    @AppStorage("com.loopkit.Loop.sharedAIModel") private var model: String = ""
    @AppStorage("com.loopkit.Loop.sharedAIEndpointPath") private var endpointPath: String = ""
    @AppStorage("com.loopkit.Loop.sharedAIAPIVersion") private var apiVersion: String = ""
    @AppStorage("com.loopkit.Loop.sharedAIOrganizationID") private var organizationID: String = ""

    @State private var apiKeyText: String = ""
    @State private var selectedPreset: AIProviderPreset = .custom
    @State private var showAPIKey: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showAdvanced: Bool = false

    private enum TestResult {
        case success
        case successWithVisionWarning(String)
        case warning(String)
        case failure(String)
    }

    private var resolvedFormat: RequestFormat {
        RequestFormat.detect(from: baseURL)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("AI PROVIDER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    Text("Choose a provider and paste your API key. Used by FoodFinder and LoopInsights.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Provider dropdown
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Provider", selection: $selectedPreset) {
                            ForEach(AIProviderPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedPreset) { newPreset in
                            if newPreset != .custom {
                                baseURL = newPreset.baseURL
                                model = newPreset.defaultModel
                                endpointPath = ""
                                testResult = nil
                                saveAndSync()
                            }
                        }
                    }

                    // Get API Key link (when preset selected)
                    if selectedPreset != .custom, !selectedPreset.apiKeySignupURL.isEmpty {
                        Button(action: { if let u = URL(string: selectedPreset.apiKeySignupURL) { openURL(u) } }) {
                            HStack(spacing: 6) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(selectedPreset.accentColor)
                                Text("Get API Key")
                                    .font(.subheadline)
                                    .foregroundColor(selectedPreset.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Base URL + Model — only for Custom
                    if selectedPreset == .custom {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Base URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("", text: $baseURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .overlay(alignment: .leading) {
                                    if baseURL.isEmpty {
                                        Text("e.g. https://api.example.com/v1")
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: baseURL) { _ in
                                    selectedPreset = AIProviderPreset.detect(from: baseURL)
                                    testResult = nil
                                    saveAndSync()
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g. gpt-4o, claude-sonnet-4-20250514", text: $model)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: model) { _ in
                                    testResult = nil
                                    saveAndSync()
                                }
                        }
                    }

                    // API Key (always shown)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Group {
                                if showAPIKey {
                                    TextField("Enter your API key", text: $apiKeyText)
                                } else {
                                    SecureField("Enter your API key", text: $apiKeyText)
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: apiKeyText) { newValue in
                                saveAPIKey(newValue)
                                testResult = nil
                            }
                            Button(action: { showAPIKey.toggle() }) {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            if !apiKeyText.isEmpty {
                                Button(action: { apiKeyText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !apiKeyText.isEmpty {
                            Text("Stored securely in Keychain")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }

                    // Test Connection
                    VStack(spacing: 8) {
                        Button(action: testConnection) {
                            HStack(spacing: 6) {
                                if isTesting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                        .tint(.black)
                                    Text("Testing...")
                                } else {
                                    Image(systemName: "checkmark.shield")
                                    Text("Test Connection")
                                }
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                        .disabled(isTesting || apiKeyText.isEmpty || baseURL.isEmpty)
                        .opacity((isTesting || apiKeyText.isEmpty || baseURL.isEmpty) ? 0.5 : 1.0)
                        .buttonStyle(.plain)

                        if let result = testResult {
                            switch result {
                            case .success:
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            case .successWithVisionWarning(let message):
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Connected")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            case .warning(let message):
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            case .failure(let message):
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For custom or self-hosted endpoints only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Endpoint Path")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Leave blank for default", text: $endpointPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .onChange(of: endpointPath) { _ in saveAndSync() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Version")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Optional", text: $apiVersion)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: apiVersion) { _ in saveAndSync() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organization ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Optional", text: $organizationID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: organizationID) { _ in saveAndSync() }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("AI Provider", comment: "AI Provider settings title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            SharedAI_Config.ensureMigrationComplete()
            baseURL = SharedAI_Config.baseURL
            model = SharedAI_Config.model
            endpointPath = SharedAI_Config.endpointPath
            apiVersion = SharedAI_Config.apiVersion
            organizationID = SharedAI_Config.organizationID
            selectedPreset = AIProviderPreset.detect(from: baseURL)
            if selectedPreset == .custom, baseURL.isEmpty {
                selectedPreset = .openAI
                baseURL = AIProviderPreset.openAI.baseURL
                model = AIProviderPreset.openAI.defaultModel
                saveAndSync()
            }
            apiKeyText = LoopInsights_SecureStorage.loadAPIKey() ?? ""
        }
    }

    private func saveAPIKey(_ key: String) {
        if key.isEmpty {
            LoopInsights_SecureStorage.deleteAPIKey()
        } else {
            try? LoopInsights_SecureStorage.saveAPIKey(key)
        }
        saveAndSync()
    }

    private func saveAndSync() {
        SharedAI_Config.save(
            baseURL: baseURL,
            model: model,
            endpointPath: endpointPath,
            apiVersion: apiVersion,
            organizationID: organizationID
        )
        SharedAI_Config.syncToFeatures()
    }

    private func testConnection() {
        guard !baseURL.isEmpty, !apiKeyText.isEmpty else { return }
        isTesting = true
        testResult = nil

        let config = AIProviderConfiguration(
            name: "AI Provider",
            baseURL: baseURL,
            model: model,
            endpointPath: endpointPath.isEmpty ? nil : endpointPath,
            requestFormat: resolvedFormat,
            apiVersion: apiVersion.isEmpty ? nil : apiVersion,
            organizationID: organizationID.isEmpty ? nil : organizationID,
            apiKey: apiKeyText
        )

        Task {
            let result = await AIServiceManager.shared.testConnection(to: config)
            await MainActor.run {
                isTesting = false
                if result.success {
                    if let code = result.statusCode, (code == 402 || code == 429) {
                        testResult = .warning(result.message)
                    } else if result.supportsVision == false {
                        testResult = .successWithVisionWarning("Connected — but this model may not support image analysis.")
                    } else {
                        testResult = .success
                    }
                } else {
                    testResult = .failure(result.message)
                }
            }
        }
    }
}
