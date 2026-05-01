//
//  ContentView.swift
//  PocketPlanWatch Watch App
//
//  Created by Nicola Consoli on 01/05/26.
//

import SwiftUI
import WatchConnectivity
import Combine

struct WatchSummary {
    var monthlyIncome: Double = 0
    var monthlyExpenses: Double = 0
    var monthlyPlannedExpenses: Double = 0
    var totalMonthlyExpenses: Double = 0
    var remainingBudget: Double = 0
    var activeGoals: Int = 0

    var mainGoalTitle: String = ""
    var mainGoalTargetAmount: Double = 0
    var mainGoalCurrentAmount: Double = 0
    var mainGoalRemainingAmount: Double = 0
    var mainGoalProgress: Double = 0
}

final class WatchSummaryViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var summary = WatchSummary()
    @Published var lastUpdateText: String = "In attesa dati"

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            lastUpdateText = "Sync non supportata"
            return
        }

        WCSession.default.delegate = self
        WCSession.default.activate()

        let context = WCSession.default.applicationContext

        if !context.isEmpty {
            updateSummary(from: context)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                self.lastUpdateText = "Errore sync"
                print("Errore attivazione WCSession Watch:", error.localizedDescription)
            } else {
                self.lastUpdateText = "Watch collegato"
                print("WCSession Watch attiva:", activationState.rawValue)
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        DispatchQueue.main.async {
            self.updateSummary(from: applicationContext)
        }
    }

    private func updateSummary(from data: [String: Any]) {
        summary = WatchSummary(
            monthlyIncome: doubleValue(data["monthly_income"]),
            monthlyExpenses: doubleValue(data["monthly_expenses"]),
            monthlyPlannedExpenses: doubleValue(data["monthly_planned_expenses"]),
            totalMonthlyExpenses: doubleValue(data["total_monthly_expenses"]),
            remainingBudget: doubleValue(data["remaining_budget"]),
            activeGoals: intValue(data["active_goals"]),
            mainGoalTitle: stringValue(data["main_goal_title"]),
            mainGoalTargetAmount: doubleValue(data["main_goal_target_amount"]),
            mainGoalCurrentAmount: doubleValue(data["main_goal_current_amount"]),
            mainGoalRemainingAmount: doubleValue(data["main_goal_remaining_amount"]),
            mainGoalProgress: doubleValue(data["main_goal_progress"])
        )

        lastUpdateText = "Aggiornato ora"
    }

    private func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double {
            return value
        }

        if let value = value as? Int {
            return Double(value)
        }

        if let value = value as? Float {
            return Double(value)
        }

        if let value = value as? String {
            return Double(value) ?? 0
        }

        return 0
    }

    private func intValue(_ value: Any?) -> Int {
        if let value = value as? Int {
            return value
        }

        if let value = value as? Double {
            return Int(value)
        }

        if let value = value as? String {
            return Int(value) ?? 0
        }

        return 0
    }

    private func stringValue(_ value: Any?) -> String {
        if let value = value as? String {
            return value
        }

        return ""
    }
}

struct ContentView: View {
    @StateObject private var viewModel = WatchSummaryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                headerView

                SummaryCard(
                    title: "Disponibile",
                    value: formatCurrency(viewModel.summary.remainingBudget),
                    isMain: true
                )

                HStack(spacing: 8) {
                    SummaryCard(
                        title: "Entrate",
                        value: formatCurrency(viewModel.summary.monthlyIncome)
                    )

                    SummaryCard(
                        title: "Spese",
                        value: formatCurrency(viewModel.summary.monthlyExpenses)
                    )
                }

                SummaryCard(
                    title: "Spese previste",
                    value: formatCurrency(viewModel.summary.monthlyPlannedExpenses)
                )

                if !viewModel.summary.mainGoalTitle.isEmpty {
                    goalView
                }

                Text(viewModel.lastUpdateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PocketPlan")
                .font(.headline)
                .fontWeight(.bold)

            Text("Controllo rapido")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var goalView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Obiettivo")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(viewModel.summary.mainGoalTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            ProgressView(
                value: viewModel.summary.mainGoalProgress,
                total: 100
            )

            HStack {
                Text("\(Int(viewModel.summary.mainGoalProgress))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(viewModel.summary.mainGoalRemainingAmount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(14)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€"
        formatter.locale = Locale(identifier: "it_IT")
        formatter.maximumFractionDigits = 0

        return formatter.string(from: NSNumber(value: value)) ?? "€0"
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    var isMain: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(isMain ? .title3 : .caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isMain ? 12 : 9)
        .background(.thinMaterial)
        .cornerRadius(14)
    }
}

#Preview {
    ContentView()
}
