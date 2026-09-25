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

                // 3. Local Data & Storage Summary
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

                    if let supportURL = URL(string: "mailto:support@homeschoolhelper.app?subject=HomeSchoolHelper%20Support") {
                        Link(destination: supportURL) {
                            Label("Contact Support & Feedback", systemImage: "envelope")
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

#Preview {
    SettingsView()
        .environmentObject(HomeschoolStore())
        .environmentObject(AuthStore(client: SupabaseConfiguration.makeClient()))
}
