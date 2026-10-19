//
//  RootView.swift
//  PaywallDemo
//

import SwiftUI

/// Hosts the paywall and the demo-mode switch.
///
/// Switching scenario swaps the whole backend: a new `PaywallModel` over either
/// `PurchasesManager.shared` or a `DemoPurchases`. The paywall itself has no idea which one
/// it got, which is the point.
struct RootView: View {
    @State private var scenario: DemoScenario
    @State private var model: PaywallModel

    init(scenario: DemoScenario = RootView.launchScenario) {
        _scenario = State(initialValue: scenario)
        _model = State(initialValue: PaywallModel(backend: scenario.makeBackend()))
    }

    var body: some View {
        NavigationStack {
            PaywallView(model: model, scenario: scenario) {
                scenario = $0
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DemoMenu(scenario: $scenario, simulatesAskToBuy: $model.simulatesAskToBuy)
                }
            }
        }
        .onChange(of: scenario) { _, newValue in
            let askToBuy = model.simulatesAskToBuy
            model = PaywallModel(backend: newValue.makeBackend())
            model.simulatesAskToBuy = askToBuy
        }
        // Keyed by the model, so switching scenario cancels the old model's observation
        // loops and starts the new one's.
        .task(id: ObjectIdentifier(model)) {
            await model.run()
        }
    }

    /// Lets a launch argument pick the starting scenario, for screenshots and UI tests:
    /// `-DemoScenario gracePeriod`.
    static var launchScenario: DemoScenario {
        UserDefaults.standard.string(forKey: "DemoScenario").flatMap(DemoScenario.init(rawValue:)) ?? .live
    }
}

/// The toolbar menu that picks what the paywall talks to.
private struct DemoMenu: View {
    @Binding var scenario: DemoScenario
    @Binding var simulatesAskToBuy: Bool

    var body: some View {
        Menu {
            // One picker, so the checkmark always sits next to the current choice.
            Picker("Store", selection: $scenario) {
                Label(DemoScenario.live.title, systemImage: DemoScenario.live.symbol)
                    .tag(DemoScenario.live)
                Section("Simulated Customer") {
                    ForEach(DemoScenario.allCases.filter { $0 != .live }) { scenario in
                        Label(scenario.title, systemImage: scenario.symbol)
                            .tag(scenario)
                    }
                }
            }
            .pickerStyle(.inline)
            Section {
                Toggle(isOn: $simulatesAskToBuy) {
                    Label("Simulate Ask to Buy", systemImage: "person.2.badge.gearshape")
                }
            } footer: {
                Text("Sets PurchaseOptions.simulatesAskToBuyInSandbox on every purchase.")
            }
        } label: {
            Label("Demo Mode", systemImage: "theatermask.and.paintbrush")
        }
        .accessibilityHint("Choose live StoreKit or a simulated subscription state")
    }
}
