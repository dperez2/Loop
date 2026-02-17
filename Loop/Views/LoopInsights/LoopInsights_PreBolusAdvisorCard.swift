//
//  LoopInsights_PreBolusAdvisorCard.swift
//  Loop
//
//  In-flow pre-bolus advice card shown on CarbEntryView.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

/// Compact card that displays AI-generated pre-bolus timing advice when entering carbs.
struct LoopInsights_PreBolusAdvisorCard: View {

    let dataProvider: LoopInsightsPreBolusDataProvider

    @State private var advice: LoopInsightsPreBolusAdvice?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("Getting pre-bolus advice...", comment: "Pre-bolus advisor loading"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let advice = advice {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(.accentColor)
                            .font(.subheadline)
                        Text(NSLocalizedString("Pre-bolus tip", comment: "Pre-bolus advisor card title"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    Text(advice.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            loadAdvice()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    private func loadAdvice() {
        guard LoopInsights_FeatureFlags.isEnabled else { return }
        guard LoopInsights_FeatureFlags.preBolusAdvisorEnabled else { return }
        guard advice == nil, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        loadTask = Task { @MainActor in
            do {
                let result = try await LoopInsights_PreBolusAdvisor.buildContextAndGenerateAdviceInFlow(provider: dataProvider)
                guard !Task.isCancelled else { return }
                if let result = result {
                    advice = result
                } else {
                    errorMessage = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
