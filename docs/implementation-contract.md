# First iOS milestone: shared implementation contract

This contract coordinates parallel implementation. No cloud, billing, grades, PDF, or rescheduling engine is part of this milestone. All app data is local. iOS 17+; Swift 5 language mode on the installed Swift toolchain.

## Ownership

- Core worker: `Sources/HomeschoolCore/` only.
- UI worker: `iOS/HomeSchoolHelper/` only.
- Test worker: `Tests/HomeschoolCoreTests/` only.
- Lead: package/project configuration, documentation, integration, review.

## Public API (exact spelling)

All value types are public, Codable, Equatable, Sendable. Entity types are Identifiable. All properties below are public stored vars unless stated otherwise. Give public initializers with `id: UUID = UUID()` for entity types. Import Foundation.

```swift
public enum AssignmentStatus: String, Codable, CaseIterable, Sendable {
    case planned, inProgress, completed, skipped
}
public struct Student { var id: UUID; var name: String; var gradeLevel: String }
public struct Course { var id: UUID; var title: String }
public struct Lesson { var id: UUID; var courseID: UUID; var title: String; var sequence: Int }
public struct Assignment {
    var id: UUID; var studentID: UUID; var lessonID: UUID
    var scheduledDay: String? // validated Gregorian YYYY-MM-DD, never a timestamp
    var status: AssignmentStatus // default .planned
    var completedDay: String? // default nil; set only when completed
}
public struct AttendanceEntry {
    var id: UUID; var studentID: UUID; var day: String; var minutes: Int
}
public struct LearningActivity {
    var id: UUID; var studentID: UUID; var title: String; var day: String; var minutes: Int
}
public struct SchoolState {
    var schemaVersion: Int // default 1
    var students: [Student] // all arrays default []
    var courses: [Course]; var lessons: [Lesson]; var assignments: [Assignment]
    var attendance: [AttendanceEntry]; var activities: [LearningActivity]
    public init() // empty state, version 1
    public func validate() throws
    @discardableResult public mutating func addStudent(name: String, gradeLevel: String) throws -> UUID
    @discardableResult public mutating func addCourse(title: String, studentIDs: [UUID], lessonTitles: [String], startDay: String?, weekdays: Set<Int> = [2,3,4,5,6]) throws -> UUID
    public mutating func setAssignmentStatus(id: UUID, status: AssignmentStatus, completedDay: String?) throws
    public mutating func confirmAttendance(studentID: UUID, day: String, minutes: Int) throws
    public mutating func logActivity(title: String, studentIDs: [UUID], day: String, minutes: Int) throws
}
public enum SchoolDay {
    public static func string(from date: Date, calendar: Calendar = .current) -> String
    public static func date(from string: String) throws -> Date
    public static func isValid(_ string: String) -> Bool
}
public protocol SchoolRepository {
    func load() throws -> SchoolState
    func save(_ state: SchoolState) throws
}
public final class JSONSchoolRepository: SchoolRepository {
    public let fileURL: URL
    public init(fileURL: URL)
    public func load() throws -> SchoolState
    public func save(_ state: SchoolState) throws
}
```

Full memberwise initializers should follow property ordering above, with defaults for optional/status members. Errors conform to LocalizedError and explain corrective action.

## Semantics and invariants

- Each student has independent assignments referencing shared lessons. Deduplicate selected student IDs; reject unknown IDs. Trim names/titles, reject empty values. Course creation generates one assignment per lesson per selected student.
- With a start day, schedule one lesson on each eligible Gregorian weekday (Calendar Sunday=1 through Saturday=7), inclusive of the start date if eligible. Undated sequences have nil scheduledDay. Nonempty weekdays in 1...7 are required for dated scheduling. Bound lesson count to 365 for this milestone.
- Completion requires a valid completedDay; other statuses clear completedDay. No status transition silently records attendance or grades. Nonexistent assignment IDs throw.
- Attendance is one record per student/day. Confirming it again updates minutes, never adds a duplicate. Range 1...1440 minutes. This is explicit total-day confirmation, not additive time per activity.
- Retrospective log creates one individual activity per selected student; minutes 0...1440. Does not create attendance automatically.
- All mutations validate input before changing state: errors leave state unchanged.
- Validation rejects unsupported schema, malformed dates, dangling references, duplicate IDs within collections, duplicate attendance(student/day), invalid minutes and blank titles. Validate status/completedDay consistency and positive sequence values.
- Repository missing file means empty state. Decode or unsupported-schema failures must throw without resetting or overwriting existing data. Save validates then atomically writes; create parent directory if needed. No automatic sample seeding.
- UI copies state, performs mutation, persists copy, then publishes it. A failed write keeps previous displayed state and presents an error.
- UI load errors block editing and offer retry; never silently replace corrupt data with an empty household.

## Acceptance

Create two students; generate shared lessons and independent assignments; complete only one child's assignment; explicitly confirm attendance; log shared retrospective learning; reload repository and retain all records. Test invalid dates, unsupported schema, no partial mutation on error, duplicate confirmation, undated and weekday scheduling, corruption preservation, and malformed state rejection.
