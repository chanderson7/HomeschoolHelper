import Foundation
import SwiftUI
#if canImport(UserNotifications)
import UserNotifications
#endif
import HomeschoolCore

public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()
    public static let morningDigestIdentifier = "homeschool_morning_digest"

    #if canImport(UserNotifications)
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined

    public init() {
        Task {
            await updateAuthorizationStatus()
        }
    }

    @MainActor
    public func updateAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await updateAuthorizationStatus()
            return granted
        } catch {
            await updateAuthorizationStatus()
            return false
        }
    }

    public func scheduleDailyMorningDigest(time: Date, state: SchoolState) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningDigestIdentifier])

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Good morning! Today's Homeschool Plan"
        content.sound = .default

        let today = SchoolDate.today
        let todayAssignments = state.assignments.filter { $0.scheduledDay == today && $0.status != .completed }
        let studentLookup = Dictionary(uniqueKeysWithValues: state.students.map { ($0.id, $0.name) })

        if todayAssignments.isEmpty {
            content.body = "No unfinished lessons scheduled for today. Have a wonderful day!"
        } else {
            let byStudent = Dictionary(grouping: todayAssignments, by: \.studentID)
            let summaries = byStudent.compactMap { (studentID, assignments) -> String? in
                guard let name = studentLookup[studentID] else { return nil }
                let count = assignments.count
                return "\(name): \(count) lesson\(count == 1 ? "" : "s")"
            }.sorted()
            if summaries.isEmpty {
                content.body = "\(todayAssignments.count) lesson\(todayAssignments.count == 1 ? "" : "s") scheduled for today."
            } else {
                content.body = summaries.joined(separator: " · ")
            }
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.morningDigestIdentifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    public func cancelDailyMorningDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.morningDigestIdentifier])
    }
    #else
    public init() {}
    #endif
}
