//
//  LoopInsights_PreBolusMonitor.swift
//  Loop
//
//  Proactive pre-bolus notifications during typical meal windows.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import UserNotifications
import os.log

/// Monitors for meal windows and delivers proactive pre-bolus advice via notifications.
/// Hooks into LoopCompleted (like BackgroundMonitor); throttled to max 1 prompt per meal window per day.
final class LoopInsights_PreBolusMonitor {

    private let coordinator: LoopInsights_Coordinator
    private var loopCompletedObserver: NSObjectProtocol?
    private var isRunningAnalysis = false

    private static let lastPromptPerWindowKey = "LoopInsights_PreBolus_lastPromptPerWindow"
    private static let maxPromptsPerDay = 3

    init(coordinator: LoopInsights_Coordinator) {
        self.coordinator = coordinator
    }

    deinit {
        stop()
    }

    func start() {
        guard loopCompletedObserver == nil else { return }
        guard LoopInsights_FeatureFlags.preBolusAdvisorEnabled else { return }
        guard LoopInsights_FeatureFlags.preBolusNotificationsEnabled else { return }
        guard coordinator.hasRealStores else { return }

        loopCompletedObserver = NotificationCenter.default.addObserver(
            forName: .LoopCompleted,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleLoopCompleted()
        }

        LoopInsights_FeatureFlags.log.info("PreBolus monitor started")
    }

    func stop() {
        if let observer = loopCompletedObserver {
            NotificationCenter.default.removeObserver(observer)
            loopCompletedObserver = nil
        }
        LoopInsights_FeatureFlags.log.info("PreBolus monitor stopped")
    }

    private func handleLoopCompleted() {
        guard LoopInsights_FeatureFlags.preBolusAdvisorEnabled else { return }
        guard LoopInsights_FeatureFlags.preBolusNotificationsEnabled else { return }
        guard !isRunningAnalysis else { return }
        guard !isInQuietHours() else { return }

        isRunningAnalysis = true

        Task {
            await runPreBolusCheck()
            await MainActor.run {
                isRunningAnalysis = false
            }
        }
    }

    private func isInQuietHours() -> Bool {
        guard LoopInsights_FeatureFlags.quietHoursEnabled else { return false }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let start = LoopInsights_FeatureFlags.quietHoursStart
        let end = LoopInsights_FeatureFlags.quietHoursEnd
        if start <= end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }

    private func runPreBolusCheck() async {
        do {
            guard let advice = try await LoopInsights_PreBolusAdvisor.buildContextAndGenerateAdvice(provider: coordinator) else {
                return
            }

            let promptCount = promptCountToday()
            guard promptCount < Self.maxPromptsPerDay else {
                LoopInsights_FeatureFlags.log.debug("PreBolus: max daily prompts reached (\(promptCount))")
                return
            }

            recordPrompt()
            await deliverNotification(advice: advice)
        } catch {
            LoopInsights_FeatureFlags.log.error("PreBolus check failed: \(error.localizedDescription)")
        }
    }

    private func promptCountToday() -> Int {
        let key = Self.lastPromptPerWindowKey
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] else {
            return 0
        }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return dict.values.filter { Date(timeIntervalSince1970: $0) >= todayStart }.count
    }

    private func recordPrompt() {
        let key = Self.lastPromptPerWindowKey
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: Double]) ?? [:]
        let windowId = "\(Calendar.current.component(.hour, from: Date()))"
        dict[windowId] = Date().timeIntervalSince1970
        UserDefaults.standard.set(dict, forKey: key)
    }

    private func deliverNotification(advice: LoopInsightsPreBolusAdvice) async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Pre-Bolus Reminder", comment: "Pre-bolus notification title")
        content.body = advice.text
        content.sound = .default
        content.categoryIdentifier = LoopInsights_BackgroundMonitor.notificationCategoryID

        let request = UNNotificationRequest(
            identifier: "LoopInsights_PreBolus_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            LoopInsights_FeatureFlags.log.info("PreBolus notification sent")
        } catch {
            LoopInsights_FeatureFlags.log.error("PreBolus notification failed: \(error.localizedDescription)")
        }
    }
}
