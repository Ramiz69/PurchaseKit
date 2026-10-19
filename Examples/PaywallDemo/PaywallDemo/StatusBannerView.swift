//
//  StatusBannerView.swift
//  PaywallDemo
//

import SwiftUI

/// Renders a `SubscriptionBanner`. All decisions were made by the banner; this only draws.
struct StatusBannerView: View {
    let banner: SubscriptionBanner
    /// Off when the paywall shows the same action in its bottom bar.
    var showsAction = true
    var isWorking = false
    let perform: (SubscriptionBanner.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(banner.title)
                    .font(.headline)
            } icon: {
                Image(systemName: banner.symbol)
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                    .imageScale(.large)
            }

            Text(banner.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if showsAction, let action = banner.action, let title = banner.actionTitle {
                Button {
                    perform(action)
                } label: {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                        }
                        Text(title)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .controlSize(.regular)
                .disabled(isWorking)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var tint: Color {
        switch banner.tone {
        case .positive: .green
        case .warning: .orange
        case .critical: .red
        case .invitation: .accentColor
        }
    }
}

/// A persistent, neutral message such as "Waiting for approval".
struct NoticeView: View {
    let notice: PaywallModel.Notice
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notice.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)
            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.headline)
                Text(notice.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
    }
}
