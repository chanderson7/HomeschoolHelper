import SwiftUI
import HomeschoolAuth
import HomeschoolCore

/// The main application Settings view, housing preferences, account sync, local storage stats,
/// and legal/privacy documentation links.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.signedInIdentity) private var identity: AuthIdentity?

    @AppStorage("app_appearance") private var appearancePreference: String = "system"
    @AppStorage("default_cadence") private var defaultCadence: String = "schoolDays"
    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true

    @State private var showAccount = false
    @State private var showPINSheet = false
    @State private var selectedLegalDocument: LegalDocumentType?
    @State private var confirmSignOut = false

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (Build \(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application Settings")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Sage.accent)
                        Text("Settings")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Account sync, display preferences, and legal information.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // 1. Account & Sync
                Section("Account & Cloud Sync") {
                    if let identity {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Sage.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(identity.email)
                                    .font(.headline)
                                Text("Signed In · Cloud Backups Ready")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)

                        Button {
                            showAccount = true
                        } label: {
                            HStack {
                                Label("Manage Backups & Restore", systemImage: "icloud.and.arrow.up")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("settingsOpenBackups")

                        Button(role: .destructive) {
                            confirmSignOut = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .accessibilityIdentifier("settingsSignOut")
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Local Storage Only", systemImage: "internaldrive")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Sign in to back up your homeschool records securely to private cloud storage.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // 2. Preferences & Appearance
                Section("Preferences") {
                    Picker("Appearance", selection: $appearancePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .accessibilityIdentifier("appearancePicker")

                    Picker("Default Schedule", selection: $defaultCadence) {
                        Text("Weekdays (Mon–Fri)").tag("schoolDays")
                        Text("Flexible (Own Pace)").tag("flexible")
                    }
                    .accessibilityIdentifier("defaultCadencePicker")

                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                        .accessibilityIdentifier("hapticsToggle")
                }

                // 3. Parental Controls & Student Mode
                Section("Parental Controls & Student Mode") {
                    Button {
                        store.enterStudentMode()
                    } label: {
                        HStack {
                            Label("Enter Student Mode", systemImage: "person.crop.circle.badge.checkmark")
                                .foregroundStyle(Sage.accent)
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Sage.accent)
                        }
                    }
                    .accessibilityIdentifier("settingsEnterStudentModeButton")

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parent Security PIN")
                                .font(.body)
                            Text(store.hasParentPIN ? "PIN Protected (4 digits active)" : "Not Configured (Unlocked)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(store.hasParentPIN ? "Change / Remove" : "Set PIN") {
                            showPINSheet = true
                        }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                    }
                    .accessibilityIdentifier("settingsConfigurePINButton")

                    Text("Student Mode provides a calm, kid-friendly checklist of today's lessons while locking out editing, records, and settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // 4. Home State Legal Compliance
                Section("Home State Legal Compliance") {
                    Picker("Home State", selection: Binding(
                        get: { store.state.selectedStateCode ?? "" },
                        set: { newCode in
                            _ = store.setSelectedStateCode(newCode.isEmpty ? nil : newCode)
                        }
                    )) {
                        Text("None Selected").tag("")
                        ForEach(StateCompliancePreset.allStates) { preset in
                            Text("\(preset.name) (\(preset.code))").tag(preset.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("settingsStateCompliancePicker")

                    if let preset = store.selectedStatePreset {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(preset.name) Statutory Benchmarks")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Sage.accent)
                                Spacer()
                                Text(preset.code)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Sage.accent.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 16) {
                                Label("\(preset.defaultDays) Days Required", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.primary)

                                if let hours = preset.defaultHours {
                                    Label("\(hours) Hours Required", systemImage: "clock")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }

                            Text(preset.regulatorySummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Select your state to view official attendance targets, legal instruction hours, and statutory compliance guidance.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // 5. Local Data & Storage Summary
                Section("Data & Storage") {
                    LabeledContent("Learners", value: "\(store.state.students.count)")
                    LabeledContent("Subjects & Courses", value: "\(store.state.courses.count)")
                    LabeledContent("Assignments & Lessons", value: "\(store.state.assignments.count)")
                    let totalAttendanceDays = Set(store.state.attendance.map(\.day)).count
                    LabeledContent("Attendance Days Recorded", value: "\(totalAttendanceDays)")

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Local-First Architecture", systemImage: "lock.shield.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Sage.accent)
                        Text("All learner details and daily progress are saved directly to this device first. Nothing is shared without your explicit action.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // 4. Legal & Privacy Policies
                Section("Legal & Privacy") {
                    Button {
                        selectedLegalDocument = .privacyPolicy
                    } label: {
                        HStack {
                            Label("Privacy Policy", systemImage: "lock.shield")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("openPrivacyPolicy")

                    Button {
                        selectedLegalDocument = .termsOfService
                    } label: {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("openTermsOfService")

                    Button {
                        selectedLegalDocument = .openSourceLicenses
                    } label: {
                        HStack {
                            Label("Open Source Licenses", systemImage: "curlybraces")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("openOpenSourceLicenses")
                }

                // 5. About & Support
                Section("About") {
                    LabeledContent("App Version", value: appVersionString)

                    if let websiteURL = URL(string: "https://homeschoohelp.netlify.app/") {
                        Link(destination: websiteURL) {
                            HStack {
                                Label("Website & Preview", systemImage: "safari")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("websiteLink")
                    }

                    if let supportPageURL = URL(string: "https://homeschoohelp.netlify.app/support/") {
                        Link(destination: supportPageURL) {
                            HStack {
                                Label("Online Support & FAQ", systemImage: "questionmark.circle")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("onlineSupportLink")
                    }

                    if let supportURL = URL(string: "mailto:support@homeschoolhelper.app?subject=HomeSchoolHelper%20Support") {
                        Link(destination: supportURL) {
                            Label("Email Support & Feedback", systemImage: "envelope")
                        }
                        .accessibilityIdentifier("contactSupportLink")
                    }

                    Text("HomeSchoolHelper is crafted to give parents and families calm, organized, and private control over their homeschool journey.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAccount) {
                if let identity {
                    AccountView(identity: identity)
                }
            }
            .sheet(item: $selectedLegalDocument) { docType in
                LegalDocumentView(documentType: docType)
            }
            .sheet(isPresented: $showPINSheet) {
                ParentPINManagementSheet()
            }
            .confirmationDialog("Are you sure you want to sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your local records will remain safely saved on this device.")
            }
            .accessibilityIdentifier("settingsView")
        }
    }
}

// MARK: - Parent PIN Management Sheet

struct ParentPINManagementSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPIN = ""
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var errorMessage: String?

    private var requiresCurrentPIN: Bool {
        store.hasParentPIN
    }

    var body: some View {
        NavigationStack {
            Form {
                if requiresCurrentPIN {
                    Section("Current PIN") {
                        SecureField("Enter Current 4-digit PIN", text: $currentPIN)
                            .keyboardType(.numberPad)
                            .textContentType(.password)
                            .accessibilityIdentifier("currentPINField")
                    }
                }

                Section("New PIN") {
                    SecureField("Enter New 4-digit PIN", text: $newPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .accessibilityIdentifier("newPINField")

                    SecureField("Confirm New 4-digit PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .accessibilityIdentifier("confirmPINField")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote.weight(.semibold))
                    }
                }

                Section {
                    Button("Save PIN") {
                        savePIN()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(Sage.accent)
                    .accessibilityIdentifier("savePINButton")

                    if store.hasParentPIN {
                        Button("Remove PIN (Unlock Student Mode)", role: .destructive) {
                            removePIN()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("removePINButton")
                    }
                }
            }
            .navigationTitle(store.hasParentPIN ? "Manage Parent PIN" : "Set Parent PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private func savePIN() {
        if requiresCurrentPIN {
            guard store.verifyParentPIN(currentPIN) else {
                errorMessage = "Current PIN is incorrect."
                return
            }
        }

        let trimmedNew = newPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPIN.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedNew.count == 4 && trimmedNew.allSatisfy(\.isNumber) else {
            errorMessage = "New PIN must be exactly 4 numeric digits."
            return
        }

        guard trimmedNew == trimmedConfirm else {
            errorMessage = "New PIN and confirmation PIN do not match."
            return
        }

        if store.setParentPIN(trimmedNew) {
            dismiss()
        } else {
            errorMessage = "Failed to save parent PIN."
        }
    }

    private func removePIN() {
        if requiresCurrentPIN {
            guard store.verifyParentPIN(currentPIN) else {
                errorMessage = "Current PIN is required to remove PIN."
                return
            }
        }
        if store.setParentPIN(nil) {
            dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HomeschoolStore())
        .environmentObject(AuthStore(client: SupabaseConfiguration.makeClient()))
}
