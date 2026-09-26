import SwiftUI
import HomeschoolAuth
import HomeschoolCore
import Supabase

struct AccountView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    @AppStorage("auto_cloud_sync_enabled") private var autoSyncEnabled = true
    let identity: AuthIdentity
    @State private var backups: [BackupSummary] = []
    @State private var busy = false
    @State private var message: String?
    @State private var pendingRestore: BackupSummary?
    @State private var confirmImport = false
    @State private var confirmUpload = false
    @State private var confirmDeleteAccount = false

    private var isCurrentAccount: Bool { auth.phase == .signedIn(identity) }
    private var legacyAvailable: Bool { FileManager.default.fileExists(atPath: HomeschoolStore.defaultFileURL().path) }

    var body: some View {
        NavigationStack {
            List {
                Section("Your account") {
                    LabeledContent("Email", value: identity.email)
                    Button("Sign out") {
                        Task { await auth.signOut() }
                    }
                    .accessibilityIdentifier("accountSignOut")

                    Button("Delete Account", role: .destructive) {
                        confirmDeleteAccount = true
                    }
                    .accessibilityIdentifier("accountDeleteButton")
                }

                Section("Automatic Cloud Sync") {
                    Toggle("Automatic Cloud Sync", isOn: $autoSyncEnabled)
                        .onChange(of: autoSyncEnabled) { _, newValue in
                            cloudSync.setAutoSyncEnabled(newValue)
                        }
                        .accessibilityIdentifier("autoSyncToggle")

                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sync Status")
                                    .font(.subheadline)
                                Text(cloudSync.syncStatus.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: cloudSync.syncStatus.systemImage)
                                .foregroundStyle(cloudSync.syncStatus == .syncing ? Sage.accent : .secondary)
                        }

                        Spacer()

                        if cloudSync.syncStatus == .syncing {
                            ProgressView()
                        } else if autoSyncEnabled {
                            Button("Sync Now") {
                                Task {
                                    await cloudSync.flushNow(state: store.state, userID: identity.id, client: auth.client)
                                    await loadBackups()
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("manualSyncNowButton")
                        }
                    }
                    .accessibilityIdentifier("cloudSyncStatusRow")

                    Text("When enabled, changes to your lessons, attendance, and grades are automatically backed up to your private cloud storage.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Cloud Backup Snapshots") {
                    Text("Historical backup snapshots saved to your Supabase account. You can restore previous states or manually trigger a new snapshot.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Save Snapshot Now") { confirmUpload = true }
                        .disabled(busy || store.loadError != nil)
                        .accessibilityIdentifier("uploadBackup")
                    Button("Refresh backups") { Task { await loadBackups() } }.disabled(busy)
                    if busy { ProgressView("Working…") }
                    if let message { Text(message).font(.footnote).accessibilityIdentifier("backupMessage") }
                    ForEach(backups) { backup in
                        Button {
                            pendingRestore = backup
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Restore backup").font(.headline)
                                Text(backup.created_at).font(.caption).foregroundStyle(.secondary)
                            }
                        }.disabled(busy)
                    }
                    if backups.isEmpty && !busy { Text("No cloud backups yet.").foregroundStyle(.secondary) }
                }
                if legacyAvailable {
                    Section("Existing device records") {
                        Text("Records created before accounts were added are kept separately. Import them only if they belong to this account. The original file will be preserved.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Import records from this device") { confirmImport = true }
                            .disabled(busy || store.state != SchoolState())
                        Text("Import is available only while this account has no records.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Account & backups")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await loadBackups() }
            .confirmationDialog("Back up this account’s records?", isPresented: $confirmUpload, titleVisibility: .visible) {
                Button("Upload private backup") { Task { await uploadBackup() } }
            } message: { Text("Learners, lessons, attendance, and activities will be saved to your Supabase account.") }
            .confirmationDialog("Replace this account’s local records?", isPresented: Binding(
                get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }
            ), titleVisibility: .visible) {
                if let backup = pendingRestore {
                    Button("Restore backup", role: .destructive) { Task { await restoreBackup(backup) } }
                }
            } message: { Text("Current local changes will be replaced with the selected backup. Back up your current records first if you want to keep them.") }
            .confirmationDialog("Import existing records into this account?", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("Import into \(identity.email)") { importLegacy() }
            } message: { Text("Only import records belonging to this family. Import does not upload them.") }
            .confirmationDialog(
                "Delete Account & Cloud Backups?",
                isPresented: $confirmDeleteAccount,
                titleVisibility: .visible
            ) {
                Button("Delete Cloud Account & Keep Device Data", role: .destructive) {
                    Task { await deleteAccount(eraseLocal: false) }
                }
                .accessibilityIdentifier("deleteAccountKeepLocalButton")

                Button("Delete Cloud Account & Erase All Device Data", role: .destructive) {
                    Task { await deleteAccount(eraseLocal: true) }
                }
                .accessibilityIdentifier("deleteAccountEraseLocalButton")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and removes all cloud backup snapshots from our servers. You can choose whether to keep your homeschool records on this device or erase them.")
            }
        }
    }

    private func verifyIdentity() async throws {
        guard isCurrentAccount else { throw BackupError.accountChanged }
        let user = try await auth.client.auth.user()
        guard user.id == identity.id, isCurrentAccount else { throw BackupError.accountChanged }
    }

    private func loadBackups() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await verifyIdentity()
            let fetched: [BackupSummary] = try await auth.client.from("school_backups")
                .select("id,created_at").eq("user_id", value: identity.id)
                .order("created_at", ascending: false).limit(20).execute().value
            guard isCurrentAccount else { return }
            backups = fetched
            message = nil
        } catch { message = "Couldn’t load backups. Check your connection and try again." }
    }

    private func uploadBackup() async {
        guard !busy, isCurrentAccount else { return }
        busy = true
        do {
            let snapshot = store.state
            try snapshot.validate()
            try await verifyIdentity()
            try await auth.client.from("school_backups")
                .insert(BackupUpload(user_id: identity.id, state: snapshot)).execute()
            guard isCurrentAccount else { busy = false; return }
            busy = false
            await loadBackups()
            message = "Private backup saved."
        } catch { busy = false; message = "Couldn’t save the backup. Your local records are unchanged." }
    }

    private func restoreBackup(_ backup: BackupSummary) async {
        guard !busy else { return }
        busy = true
        defer { busy = false; pendingRestore = nil }
        do {
            try await verifyIdentity()
            let stored: BackupContents = try await auth.client.from("school_backups")
                .select("state").eq("user_id", value: identity.id).eq("id", value: backup.id)
                .single().execute().value
            try stored.state.validate()
            guard isCurrentAccount else { return }
            if store.restore(stored.state) { message = "Records restored on this device." }
            else { message = "Couldn’t save restored records. Your previous local records are unchanged." }
        } catch { message = "Couldn’t restore this backup. Your local records are unchanged." }
    }

    private func importLegacy() {
        guard isCurrentAccount, store.state == SchoolState() else { return }
        do {
            let snapshot = try JSONSchoolRepository(fileURL: HomeschoolStore.defaultFileURL()).load()
            message = store.restore(snapshot) ? "Device records imported. The original file is unchanged." : "Couldn’t import records."
        } catch { message = "The existing records couldn’t be read. The original file is unchanged." }
    }

    private func deleteAccount(eraseLocal: Bool) async {
        guard !busy, isCurrentAccount else { return }
        busy = true
        defer { busy = false }
        do {
            try await verifyIdentity()
            // 1. Delete all backups for this user from cloud database
            try? await auth.client.from("school_backups").delete().eq("user_id", value: identity.id).execute()
            // 2. Delete remote account
            await auth.deleteAccount()
            // 3. If requested, wipe local data
            if eraseLocal {
                store.eraseAllData()
            }
            dismiss()
        } catch {
            message = "Couldn’t delete account. Please check your connection and try again."
        }
    }
}

private struct BackupSummary: Decodable, Identifiable {
    let id: UUID
    let created_at: String
}
private struct BackupUpload: Encodable { let user_id: UUID; let state: SchoolState }
private struct BackupContents: Decodable { let state: SchoolState }
private enum BackupError: Error { case accountChanged }
