//
//  SharedAI_Config.swift
//  Loop
//
//  App-wide AI provider configuration. One source of truth for FoodFinder and LoopInsights.
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// Shared AI provider configuration used by FoodFinder and LoopInsights.
/// Migrates from feature-specific storage on first access.
enum SharedAI_Config {

    private enum Keys {
        static let baseURL = "com.loopkit.Loop.sharedAIBaseURL"
        static let model = "com.loopkit.Loop.sharedAIModel"
        static let endpointPath = "com.loopkit.Loop.sharedAIEndpointPath"
        static let apiVersion = "com.loopkit.Loop.sharedAIAPIVersion"
        static let organizationID = "com.loopkit.Loop.sharedAIOrganizationID"
        static let migrationComplete = "com.loopkit.Loop.sharedAIMigrationComplete"
    }

    private static let loopInsightsConfigKey = "LoopInsights_aiConfiguration"

    private static let defaults = UserDefaults.standard

    // MARK: - Public Accessors

    static var baseURL: String {
        get {
            migrateIfNeeded()
            return defaults.string(forKey: Keys.baseURL) ?? ""
        }
        set { defaults.set(newValue, forKey: Keys.baseURL) }
    }

    static var model: String {
        get {
            migrateIfNeeded()
            return defaults.string(forKey: Keys.model) ?? ""
        }
        set { defaults.set(newValue, forKey: Keys.model) }
    }

    static var endpointPath: String {
        get {
            migrateIfNeeded()
            return defaults.string(forKey: Keys.endpointPath) ?? ""
        }
        set { defaults.set(newValue, forKey: Keys.endpointPath) }
    }

    static var apiVersion: String {
        get {
            migrateIfNeeded()
            return defaults.string(forKey: Keys.apiVersion) ?? ""
        }
        set { defaults.set(newValue, forKey: Keys.apiVersion) }
    }

    static var organizationID: String {
        get {
            migrateIfNeeded()
            return defaults.string(forKey: Keys.organizationID) ?? ""
        }
        set { defaults.set(newValue, forKey: Keys.organizationID) }
    }

    static func save(baseURL: String, model: String, endpointPath: String = "", apiVersion: String = "", organizationID: String = "") {
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(model, forKey: Keys.model)
        defaults.set(endpointPath, forKey: Keys.endpointPath)
        defaults.set(apiVersion, forKey: Keys.apiVersion)
        defaults.set(organizationID, forKey: Keys.organizationID)
    }

    /// Sync shared config to FoodFinder's aiProviderConfigurations and LoopInsights' aiConfiguration.
    static func syncToFeatures() {
        syncToFoodFinder()
        syncToLoopInsights()
    }

    /// Call once at app/feature launch to ensure migration from legacy configs runs.
    static func ensureMigrationComplete() {
        migrateIfNeeded()
    }

    // MARK: - Migration

    private static func migrateIfNeeded() {
        guard !defaults.bool(forKey: Keys.migrationComplete) else { return }

        let existingBaseURL: String
        let existingModel: String
        let existingEndpointPath: String
        let existingApiVersion: String
        let existingOrgID: String

        let ffBase = defaults.string(forKey: FoodFinder_FeatureFlags.Keys.customAIBaseURL) ?? ""
        let ffModel = defaults.string(forKey: FoodFinder_FeatureFlags.Keys.customAIModel) ?? ""

        if !ffBase.isEmpty {
            existingBaseURL = ffBase
            existingModel = ffModel
            existingEndpointPath = defaults.string(forKey: FoodFinder_FeatureFlags.Keys.customAIEndpointPath) ?? ""
            existingApiVersion = defaults.string(forKey: FoodFinder_FeatureFlags.Keys.customAIAPIVersion) ?? ""
            existingOrgID = defaults.string(forKey: FoodFinder_FeatureFlags.Keys.customAIOrganization) ?? ""
        } else if let data = defaults.data(forKey: loopInsightsConfigKey),
                  let config = try? JSONDecoder().decode(LoopInsightsAIProviderConfiguration.self, from: data) {
            existingBaseURL = config.baseURL
            existingModel = config.model
            existingEndpointPath = config.endpointPath
            existingApiVersion = config.apiVersion ?? ""
            existingOrgID = config.organizationID ?? ""
        } else {
            existingBaseURL = ""
            existingModel = ""
            existingEndpointPath = ""
            existingApiVersion = ""
            existingOrgID = ""
        }

        if !existingBaseURL.isEmpty {
            defaults.set(existingBaseURL, forKey: Keys.baseURL)
            defaults.set(existingModel, forKey: Keys.model)
            defaults.set(existingEndpointPath, forKey: Keys.endpointPath)
            defaults.set(existingApiVersion, forKey: Keys.apiVersion)
            defaults.set(existingOrgID, forKey: Keys.organizationID)
        }

        defaults.set(true, forKey: Keys.migrationComplete)
    }

    // MARK: - Sync to Features

    private static func syncToFoodFinder() {
        let format = RequestFormat.detect(from: baseURL)
        let config = AIProviderConfiguration(
            name: "AI Provider",
            baseURL: baseURL,
            model: model,
            endpointPath: endpointPath.isEmpty ? nil : endpointPath,
            requestFormat: format,
            apiVersion: apiVersion.isEmpty ? nil : apiVersion,
            organizationID: organizationID.isEmpty ? nil : organizationID
        )

        var configs = UserDefaults.standard.aiProviderConfigurations
        let existingID = configs.first?.id ?? config.id
        var updated = config
        updated.id = existingID
        if configs.isEmpty {
            configs = [updated]
        } else {
            configs[0] = updated
        }
        UserDefaults.standard.aiProviderConfigurations = configs
        UserDefaults.standard.activeAIProviderConfigurationId = existingID
    }

    private static func syncToLoopInsights() {
        let format = LoopInsightsRequestFormat.detect(from: baseURL)
        var config = LoopInsightsAIProviderConfiguration(
            baseURL: baseURL,
            model: model,
            endpointPath: endpointPath.isEmpty ? nil : endpointPath,
            requestFormat: format,
            apiVersion: apiVersion.isEmpty ? nil : apiVersion,
            organizationID: organizationID.isEmpty ? nil : organizationID
        )
        LoopInsights_FeatureFlags.aiConfiguration = config
    }
}
