import SwiftUI
import StoreKit

public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedProductID: String = SubscriptionManager.annualProductID
    @State private var activeLegalDoc: LegalDocumentType?
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false
    @State private var showManageSubscriptions: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Hero
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.2), Sage.accent.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Image(systemName: "sparkles")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, Sage.accent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("HomeSchool Helper Pro")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text("Everything you need to organize, grade, record, and preserve your homeschool journey.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)

                    // Value Propositions List
                    VStack(spacing: 14) {
                        proFeatureRow(
                            icon: "person.3.fill",
                            color: .blue,
                            title: "Unlimited Students & Courses",
                            subtitle: "Add as many learners, custom grade levels, and classes as you need."
                        )

                        proFeatureRow(
                            icon: "chart.bar.doc.horizontal.fill",
                            color: .green,
                            title: "Report Cards & Weighted GPA",
                            subtitle: "Generate official PDF report cards, honor rolls, and high school transcripts."
                        )

                        proFeatureRow(
                            icon: "photo.stack.fill",
                            color: .purple,
                            title: "Unlimited Portfolio Photos",
                            subtitle: "Capture science projects, art, and assignments with high-res storage."
                        )

                        proFeatureRow(
                            icon: "icloud.and.arrow.up.fill",
                            color: .indigo,
                            title: "Automatic Cloud Sync",
                            subtitle: "Seamless multi-device sync with instant background backups."
                        )

                        proFeatureRow(
                            icon: "barcode.viewfinder",
                            color: .orange,
                            title: "ISBN Book Scanner",
                            subtitle: "Scan book barcodes to instantly populate titles and reading logs."
                        )
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)

                    // Product Plan Selection
                    VStack(spacing: 12) {
                        if subscriptionManager.products.isEmpty {
                            // Fallback preview placeholders while products load or offline
                            planCard(
                                productID: SubscriptionManager.annualProductID,
                                title: "Annual Membership",
                                price: "$39.99 / year",
                                trialText: "Includes 7-day free trial",
                                badge: "SAVE 33%",
                                isSelected: selectedProductID == SubscriptionManager.annualProductID
                            )

                            planCard(
                                productID: SubscriptionManager.monthlyProductID,
                                title: "Monthly Membership",
                                price: "$4.99 / month",
                                trialText: "Flexible month-to-month",
                                badge: nil,
                                isSelected: selectedProductID == SubscriptionManager.monthlyProductID
                            )
                        } else {
                            ForEach(subscriptionManager.products) { product in
                                let isAnnual = product.id == SubscriptionManager.annualProductID
                                planCard(
                                    productID: product.id,
                                    title: product.displayName,
                                    price: product.displayPrice + (isAnnual ? " / year" : " / month"),
                                    trialText: isAnnual ? "Includes 7-day free trial" : "Billed monthly",
                                    badge: isAnnual ? "BEST VALUE" : nil,
                                    isSelected: selectedProductID == product.id
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Error Banner if any
                    if let err = subscriptionManager.purchaseError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }

                    // Main Action CTA
                    VStack(spacing: 12) {
                        if subscriptionManager.isPro {
                            VStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.headline)
                                        .foregroundStyle(Sage.accent)
                                    Text("You have an active Pro Membership")
                                        .font(.headline)
                                }
                                .padding(.vertical, 4)

                                Button {
                                    showManageSubscriptions = true
                                } label: {
                                    HStack {
                                        Image(systemName: "gearshape")
                                        Text("Manage Subscription")
                                            .font(.headline.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Sage.accent)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .accessibilityIdentifier("manageProButton")
                            }
                        } else {
                            Button {
                                Task {
                                    await handlePurchase()
                                }
                            } label: {
                                HStack {
                                    if subscriptionManager.isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                            .padding(.trailing, 4)
                                    }
                                    Text(ctaButtonText)
                                        .font(.headline.weight(.bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.accentColor, Sage.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Sage.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(subscriptionManager.isPurchasing)
                            .accessibilityIdentifier("purchaseProButton")
                        }

                        HStack(spacing: 16) {
                            Button {
                                Task {
                                    await handleRestore()
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(subscriptionManager.isPurchasing)
                            .accessibilityIdentifier("restorePurchasesButton")

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Button {
                                showManageSubscriptions = true
                            } label: {
                                Text("Manage Subscriptions")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("manageSubscriptionsButton")
                        }
                    }
                    .padding(.horizontal)

                    // Legal & Terms of Service Footer
                    VStack(spacing: 8) {
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours prior to the end of the current period. Manage or cancel anytime in your Apple ID Account Settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        HStack(spacing: 16) {
                            Button("Terms of Use (EULA)") {
                                activeLegalDoc = .termsOfService
                            }
                            .font(.caption.weight(.medium))

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Button("Privacy Policy") {
                                activeLegalDoc = .privacyPolicy
                            }
                            .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Sage.accent)
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Sage.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .accessibilityLabel("Close Paywall")
                    .accessibilityIdentifier("closePaywall")
                }
            }
            .sheet(item: $activeLegalDoc) { doc in
                LegalDocumentView(documentType: doc)
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .alert("Subscription", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .onChange(of: subscriptionManager.isPro) { _, isPro in
                if isPro {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private func proFeatureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    private func planCard(
        productID: String,
        title: String,
        price: String,
        trialText: String,
        badge: String?,
        isSelected: Bool
    ) -> some View {
        Button {
            selectedProductID = productID
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Sage.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text(trialText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Sage.accent : Color(uiColor: .tertiaryLabel))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Sage.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var ctaButtonText: String {
        if selectedProductID == SubscriptionManager.annualProductID {
            return "Start 7-Day Free Trial"
        } else {
            return "Subscribe Now"
        }
    }

    private func handlePurchase() async {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else {
            // If offline or StoreKit config not bundled in simulator, fallback to error alert
            alertMessage = "Unable to connect to the App Store. Please verify your connection or try again."
            showAlert = true
            return
        }

        do {
            let success = try await subscriptionManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func handleRestore() async {
        do {
            try await subscriptionManager.restorePurchases()
            if subscriptionManager.isPro {
                alertMessage = "Your HomeSchool Helper Pro subscription was successfully restored!"
                showAlert = true
            } else {
                alertMessage = "No active subscription found for this Apple ID."
                showAlert = true
            }
        } catch {
            alertMessage = "Restore failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
