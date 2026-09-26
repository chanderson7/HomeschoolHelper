import Foundation
import Combine
import HomeschoolCore
import Supabase

@MainActor
public final class CloudSyncManager: ObservableObject {
    public static let shared = CloudSyncManager()

    public enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case offline
        case failed(String)
        case disabled

        public var displayText: String {
            switch self {
            case .idle:
                return "Ready"
            case .syncing:
                return "Syncing to cloud…"
            case .synced(let date):
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
            case .offline:
                return "Offline · Saved locally"
            case .failed(let err):
                return "Sync paused: \(err)"
            case .disabled:
                return "Auto-sync paused"
            }
        }

        public var systemImage: String {
            switch self {
            case .idle:
                return "checkmark.icloud"
            case .syncing:
                return "arrow.triangle.2.circlepath"
            case .synced:
                return "checkmark.icloud.fill"
            case .offline:
                return "bolt.horizontal.circle"
            case .failed:
                return "exclamationmark.icloud"
            case .disabled:
                return "icloud.slash"
            }
        }
    }

    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date? = nil

    private var debounceTask: Task<Void, Never>?
    private var lastSyncedHash: Int?

    public init() {
        UserDefaults.standard.register(defaults: [
            "auto_cloud_sync_enabled": true
        ])
    }

    public var isAutoSyncEnabled: Bool {
        UserDefaults.standard.object(forKey: "auto_cloud_sync_enabled") as? Bool ?? true
    }

    public func setAutoSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "auto_cloud_sync_enabled")
        if !enabled {
            debounceTask?.cancel()
            debounceTask = nil
            syncStatus = .disabled
        } else {
            syncStatus = .idle
        }
    }

    public func scheduleAutoSync(state: SchoolState, userID: UUID, client: SupabaseClient) {
        guard isAutoSyncEnabled else {
            syncStatus = .disabled
            return
        }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            // 5 second debounced window for rapid successive changes
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }

            await self?.performSync(state: state, userID: userID, client: client)
        }
    }

    public func flushNow(state: SchoolState, userID: UUID, client: SupabaseClient) async {
        debounceTask?.cancel()
        debounceTask = nil
        await performSync(state: state, userID: userID, client: client)
    }

    private func performSync(state: SchoolState, userID: UUID, client: SupabaseClient) async {
        guard isAutoSyncEnabled else {
            syncStatus = .disabled
            return
        }

        do {
            try state.validate()
        } catch {
            syncStatus = .failed("Invalid records: \(error.localizedDescription)")
            return
        }

        let currentHash = try? JSONEncoder().encode(state).hashValue
        if let currentHash, currentHash == lastSyncedHash {
            if case .synced = syncStatus { return }
            if let last = lastSyncDate {
                syncStatus = .synced(last)
            } else {
                syncStatus = .idle
            }
            return
        }

        syncStatus = .syncing

        do {
            struct BackupUpload: Encodable {
                let user_id: UUID
                let state: SchoolState
            }

            try await client.from("school_backups")
                .insert(BackupUpload(user_id: userID, state: state))
                .execute()

            let now = Date()
            lastSyncDate = now
            lastSyncedHash = currentHash
            syncStatus = .synced(now)
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("network") || desc.contains("connection") || desc.contains("offline") || desc.contains("internet") {
                syncStatus = .offline
            } else {
                syncStatus = .failed("Cloud sync paused. Local data safe.")
            }
        }
    }
}
