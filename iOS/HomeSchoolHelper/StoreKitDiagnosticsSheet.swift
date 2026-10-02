import SwiftUI
import StoreKit

struct StoreKitDiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var customIDInput = ""
    @State private var isQueryingCustom = false
    @State private var customQueryResult: String? = nil

    private var isSandbox: Bool {
        SubscriptionManager.isSandboxEnvironment
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: TestFlight Beta Tester Unlock
                if isSandbox {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "flask.fill")
                                    .foregroundStyle(.purple)
                                    .font(.title3)
                                Text("TestFlight Sandbox Mode")
                                    .font(.headline)
                            }

                            Text("If Apple's Paid Applications Agreement is still processing in App Store Connect, you can activate Pro access directly to test report cards, GPA, and portfolio features.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button {
                                subscriptionManager.toggleTestFlightBypass(enabled: !subscriptionManager.isTestFlightBypassActive)
                            } label: {
                                HStack {
                                    Image(systemName: subscriptionManager.isTestFlightBypassActive ? "checkmark.circle.fill" : "sparkles")
                                    Text(subscriptionManager.isTestFlightBypassActive ? "Pro Active (Tap to Disable)" : "Unlock TestFlight Pro Access")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(subscriptionManager.isTestFlightBypassActive ? Color.gray.opacity(0.2) : Sage.accent)
                                .foregroundStyle(subscriptionManager.isTestFlightBypassActive ? Color.primary : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Beta Testing Access")
                    }
                }

                // Section 2: Environment Info
                Section("StoreKit Environment") {
                    HStack {
                        Text("App Bundle ID")
                        Spacer()
                        Text(Bundle.main.bundleIdentifier ?? "Unknown")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(isSandbox ? "TestFlight / Sandbox" : "Production App Store")
                            .foregroundStyle(isSandbox ? .purple : .green)
                            .font(.footnote.weight(.semibold))
                    }

                    HStack {
                        Text("Pro Status")
                        Spacer()
                        Text(subscriptionManager.isPro ? "Active Pro" : "Free Tier")
                            .foregroundStyle(subscriptionManager.isPro ? Sage.accent : .secondary)
                            .font(.footnote.weight(.semibold))
                    }

                    HStack {
                        Text("Products Loaded")
                        Spacer()
                        Text("\(subscriptionManager.products.count) products")
                            .font(.footnote)
                            .foregroundStyle(subscriptionManager.products.isEmpty ? .red : .green)
                    }
                }

                // Section 3: Queried Product IDs
                Section("Queried Product IDs") {
                    ForEach(subscriptionManager.queriedProductIDs, id: \.self) { id in
                        let loaded = subscriptionManager.products.contains { $0.id == id }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(id)
                                    .font(.caption.monospaced())
                                Text(loaded ? "Found in StoreKit" : "Not returned by Apple")
                                    .font(.caption2)
                                    .foregroundStyle(loaded ? .green : .secondary)
                            }
                            Spacer()
                            Image(systemName: loaded ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(loaded ? .green : .secondary)
                        }
                    }

                    Button {
                        Task {
                            await subscriptionManager.loadProducts()
                        }
                    } label: {
                        HStack {
                            if subscriptionManager.isLoadingProducts {
                                ProgressView().scaleEffect(0.8)
                            }
                            Text("Re-query Apple StoreKit Now")
                        }
                    }
                    .disabled(subscriptionManager.isLoadingProducts)
                }

                // Section 4: Test Custom Product ID
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter the exact Product ID configured in App Store Connect to test if Apple returns it:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("e.g. com.mysite.pro.annual", text: $customIDInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.footnote.monospaced())

                            Button("Test") {
                                Task {
                                    isQueryingCustom = true
                                    await subscriptionManager.addCustomProductID(customIDInput)
                                    isQueryingCustom = false
                                    let found = subscriptionManager.products.contains { $0.id == customIDInput }
                                    customQueryResult = found ? "Success: Apple returned product \(customIDInput)" : "Apple returned 0 products for \(customIDInput)"
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Sage.accent)
                            .disabled(customIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isQueryingCustom)
                        }

                        if let result = customQueryResult {
                            Text(result)
                                .font(.caption2.bold())
                                .foregroundStyle(result.contains("Success") ? .green : .red)
                        }
                    }
                } header: {
                    Text("Custom Product ID Tester")
                }

                // Section 5: App Store Connect Checklist
                Section("App Store Connect Checklist") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("1. Paid Applications Agreement", systemImage: "doc.text.fill")
                            .font(.subheadline.bold())
                        Text("In App Store Connect → Agreements, Tax, and Banking, verify the Paid Apps Agreement is Active (green). Apple returns 0 products until this is active.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("2. Subscription Configuration", systemImage: "cart.fill")
                            .font(.subheadline.bold())
                        Text("In App Store Connect → Subscriptions, verify each plan has: Pricing, English Localization, and an App Review Screenshot uploaded.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("3. Sandbox Apple ID", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.bold())
                        Text("On your iPhone, go to Settings → App Store → Sandbox Account and sign in with a sandbox tester account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("StoreKit Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
