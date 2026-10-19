//
//  PaywallView.swift
//  PaywallDemo
//

import RKPurchaseKit
import SwiftUI

/// The paywall. Reads everything from `PaywallModel` and never touches StoreKit itself.
struct PaywallView: View {
    @Bindable var model: PaywallModel
    let scenario: DemoScenario
    /// Lets the empty state offer a way into demo mode.
    var switchScenario: (DemoScenario) -> Void = { _ in }

    @State private var bannerActionRunning = false

    var body: some View {
        content
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ScenarioBadge(scenario: scenario)
                }
            }
            .alert(
                "Purchase Failed",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Loading products…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView {
                Label("No Products", systemImage: "cart.badge.questionmark")
            } description: {
                Text("StoreKit returned no products. Run the PaywallDemo scheme from Xcode so it loads PaywallDemo.storekit, or try a simulated customer.")
            } actions: {
                Button("Show a Simulated Customer") {
                    switchScenario(.gracePeriod)
                }
                .buttonStyle(.borderedProminent)
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load Products", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await model.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded:
            paywall
        }
    }

    private var paywall: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // The status comes first: it is the one thing on this screen that is
                    // about this customer rather than about the product.
                    if let banner = model.banner {
                        StatusBannerView(
                            banner: banner,
                            showsAction: !banner.isRecoverable,
                            isWorking: bannerActionRunning
                        ) { action in
                            perform(action, proxy: proxy)
                        }
                        .transition(.blurReplace)
                    }

                    Header(hasPremium: model.hasPremium, isOnHold: model.status?.state == .inBillingRetryPeriod)

                    if let notice = model.notice {
                        NoticeView(notice: notice) { model.notice = nil }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    FeatureList()

                    // A customer in grace period or billing retry still has a subscription.
                    // Offering them plans invites a second, duplicate purchase.
                    if model.banner?.isRecoverable != true {
                        plans
                            .id(Self.plansAnchor)
                    }

                    extras

                    Button {
                        Task { await model.restore() }
                    } label: {
                        if model.isRestoring {
                            ProgressView()
                        } else {
                            Text("Restore Purchases")
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                    .disabled(model.isRestoring)

                    Text("Subscriptions renew automatically until cancelled. Cancel anytime in Settings at least 24 hours before the end of the current period.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .animation(.smooth, value: model.banner)
                .animation(.smooth, value: model.notice)
            }
            .safeAreaBar(edge: .bottom) {
                if let banner = model.banner, banner.isRecoverable {
                    RecoveryAction(banner: banner, isWorking: bannerActionRunning) {
                        run { await model.manageSubscription() }
                    }
                } else {
                    CallToAction(model: model)
                }
            }
            .refreshable { await model.load() }
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Choose a Plan")
            ForEach(model.plans, id: \.productID) { product in
                PlanCard(
                    product: product,
                    introOffer: model.introOffer(for: product),
                    isSelected: model.selectedPlanID == product.productID,
                    isCurrent: model.isCurrentPlan(product)
                ) {
                    model.selectedPlanID = product.productID
                }
            }
        }
    }

    @ViewBuilder
    private var extras: some View {
        if !model.extras.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionTitle("One-Time Purchases")
                    Spacer()
                    if model.coinBalance > 0 {
                        Label("\(model.coinBalance)", systemImage: "circle.hexagongrid.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                VStack(spacing: 0) {
                    ForEach(model.extras, id: \.productID) { product in
                        ExtraRow(
                            product: product,
                            // Consumables are never "owned": they can be bought again.
                            isOwned: product.type != .consumable && model.entitledProductIDs.contains(product.productID),
                            isPurchasing: model.purchasingProductID == product.productID
                        ) {
                            Task { await model.purchase(product) }
                        }
                        if product.productID != model.extras.last?.productID {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.background.secondary, in: .rect(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private static let plansAnchor = "plans"

    private func perform(_ action: SubscriptionBanner.Action, proxy: ScrollViewProxy) {
        switch action {
        case .resubscribe:
            withAnimation { proxy.scrollTo(Self.plansAnchor, anchor: .top) }
        case .manageSubscription:
            run { await model.manageSubscription() }
        case .winBack(let offerID):
            run { await model.redeemWinBack(offerID: offerID) }
        case .promotionalOffer(let offerID):
            run { await model.redeemPromotionalOffer(offerID: offerID) }
        }
    }

    private func run(_ work: @escaping @MainActor () async -> Void) {
        bannerActionRunning = true
        Task {
            await work()
            bannerActionRunning = false
        }
    }
}

// MARK: - Pieces

/// Replaces the purchase button while a subscription only needs its payment fixed.
private struct RecoveryAction: View {
    let banner: SubscriptionBanner
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    Label(banner.actionTitle ?? "Manage Subscription", systemImage: "creditcard")
                        .opacity(isWorking ? 0 : 1)
                    if isWorking { ProgressView() }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(banner.tone == .warning ? .orange : .red)
            .controlSize(.large)
            .disabled(isWorking)

            Text("Opens your App Store subscription settings. No new purchase needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: 560)
    }
}

/// The purchase button for the selected plan, pinned above the home indicator.
private struct CallToAction: View {
    let model: PaywallModel

    var body: some View {
        if let plan {
            VStack(spacing: 8) {
                Button {
                    Task { await model.purchase(plan) }
                } label: {
                    ZStack {
                        Text(title(for: plan)).opacity(isPurchasing ? 0 : 1)
                        if isPurchasing { ProgressView() }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(isCurrent || isPurchasing)

                Text(finePrint(for: plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: 560)
        }
    }

    private var plan: StoreProduct? {
        model.plans.first { $0.productID == model.selectedPlanID }
    }

    private var isPurchasing: Bool { model.purchasingProductID == plan?.productID }
    private var isCurrent: Bool { plan.map(model.isCurrentPlan) ?? false }

    private func title(for plan: StoreProduct) -> String {
        if isCurrent { return "Your Current Plan" }
        if let offer = model.introOffer(for: plan), offer.paymentMode == .freeTrial {
            return "Start Free Trial"
        }
        if model.status?.isActive == true { return "Switch to \(plan.displayName)" }
        return "Subscribe for \(OfferText.price(of: plan))"
    }

    private func finePrint(for plan: StoreProduct) -> String {
        if let offer = model.introOffer(for: plan) {
            return "\(OfferText.describe(offer, then: plan)). Cancel anytime."
        }
        return "\(OfferText.price(of: plan)). Cancel anytime."
    }
}

private struct Header: View {
    let hasPremium: Bool
    /// Billing retry: no access right now, but the customer is still a subscriber. A
    /// "Unlock Premium" headline here would read like the pitch for someone who never paid.
    let isOnHold: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: hasPremium ? "crown.fill" : isOnHold ? "pause.fill" : "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(
                    LinearGradient(
                        colors: [.accentColor, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .purple.opacity(0.3), radius: 12, y: 6)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            Text(hasPremium ? "You're Premium" : isOnHold ? "Premium Is on Hold" : "Unlock Premium")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(hasPremium
                 ? "Thanks for your support. Every feature is unlocked."
                 : isOnHold
                    ? "Your features come back as soon as the payment goes through."
                    : "Every feature, on every device, with new ones every month.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct FeatureList: View {
    private let features: [(symbol: String, title: String, detail: String)] = [
        ("wand.and.stars", "Smart Tools", "Pro editing tools that do the busy work."),
        ("icloud.fill", "Sync Everywhere", "Your library on iPhone, iPad and Mac."),
        ("lock.shield.fill", "Private by Design", "No ads, no tracking, ever."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(features, id: \.title) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.symbol)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.headline)
                        Text(feature.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }
}

/// Makes it obvious in screenshots and recordings which store is answering.
private struct ScenarioBadge: View {
    let scenario: DemoScenario

    var body: some View {
        Label(scenario == .live ? "Live StoreKit" : "Demo · \(scenario.title)", systemImage: scenario.symbol)
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(scenario == .live ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Previews

// Each preview runs the real screen against `DemoPurchases`. No StoreKit configuration,
// no simulator account, no network.

#Preview("New customer") { PaywallPreview(.newCustomer) }
#Preview("Subscribed") { PaywallPreview(.subscribed) }
#Preview("Grace period") { PaywallPreview(.gracePeriod) }
#Preview("Billing retry") { PaywallPreview(.billingRetry) }
#Preview("Expired: cancelled") { PaywallPreview(.expiredCancelled) }
#Preview("Expired: billing error") { PaywallPreview(.expiredBillingError) }
#Preview("Revoked") { PaywallPreview(.revoked) }

private struct PaywallPreview: View {
    let scenario: DemoScenario
    @State private var model: PaywallModel

    init(_ scenario: DemoScenario) {
        self.scenario = scenario
        _model = State(initialValue: PaywallModel(backend: DemoPurchases(scenario: scenario)))
    }

    var body: some View {
        NavigationStack {
            PaywallView(model: model, scenario: scenario)
        }
        .task { await model.run() }
    }
}
