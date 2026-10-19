//
//  ProductViews.swift
//  PaywallDemo
//

import RKPurchaseKit
import SwiftUI

/// One subscription plan, selectable like a radio button.
struct PlanCard: View {
    let product: StoreProduct
    /// Only passed when this customer is eligible for it.
    let introOffer: SubscriptionOffer?
    let isSelected: Bool
    let isCurrent: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 4) {
                    if isCurrent {
                        Tag(text: "Current Plan", tint: .green)
                    } else if let introOffer {
                        Tag(text: OfferText.summary(of: introOffer).uppercased(), tint: .accentColor)
                    }
                    Text(product.displayName)
                        .font(.headline)
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .monospacedDigit()
                    if let period = product.subscriptionPeriod {
                        Text("per \(OfferText.period(period))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(.background.secondary, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.snappy, value: isSelected)
    }

    private var caption: String {
        if let introOffer {
            return OfferText.describe(introOffer, then: product)
        }
        // Show the monthly equivalent of a yearly plan, the comparison customers make anyway.
        if product.subscriptionPeriod == StoreSubscriptionPeriod(value: 1, unit: .year) {
            // Format with the storefront's style, which StoreKit provides on the live
            // product, so it matches `displayPrice`. The demo catalog is in US dollars.
            let style = product.product?.priceFormatStyle
                ?? Decimal.FormatStyle.Currency(code: product.currencyCode, locale: Locale(identifier: "en_US"))
            let monthly = (product.price / 12).formatted(style.precision(.fractionLength(2)))
            return "Just \(monthly)/month, billed yearly"
        }
        return product.description
    }
}

/// A one-time purchase: a consumable or a non-consumable.
struct ExtraRow: View {
    let product: StoreProduct
    let isOwned: Bool
    let isPurchasing: Bool
    let buy: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: product.type == .consumable ? "circle.hexagongrid.fill" : "infinity.circle.fill")
                .font(.title)
                .foregroundStyle(product.type == .consumable ? Color.yellow : Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isOwned {
                Label("Owned", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button(action: buy) {
                    ZStack {
                        // Keeps the button the same width while the spinner shows.
                        Text(product.displayPrice).opacity(isPurchasing ? 0 : 1)
                        if isPurchasing { ProgressView() }
                    }
                    .monospacedDigit()
                    .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(isPurchasing)
                .accessibilityLabel("Buy \(product.displayName), \(product.displayPrice)")
            }
        }
        .padding(.vertical, 6)
    }
}

/// A small capsule label.
struct Tag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: .capsule)
            .lineLimit(1)
    }
}
