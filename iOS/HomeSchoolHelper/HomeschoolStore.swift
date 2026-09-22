import Foundation
import Combine
import HomeschoolCore

@MainActor
final class HomeschoolStore: ObservableObject {
    @Published private(set) var state = SchoolState()
    @Published private(set) var loadError: String?
    @Published var presentedError: AppMessage?
    @Published private(set) var isSaving = false

    private let repository: any SchoolRepository

    init(repository: (any SchoolRepository)? = nil) {
        self.repository = repository ?? JSONSchoolRepository(fileURL: Self.defaultFileURL())
        load()
    }

    func load() {
        do {
            let loaded = try repository.load()
            state = loaded
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// A mutation is only published after its fully validated copy has been saved.
    @discardableResult
    func update(_ action: String, _ mutation: (inout SchoolState) throws -> Void) -> Bool {
        guard loadError == nil else { return false }
        var copy = state
        do {
            try mutation(&copy)
            isSaving = true
            try repository.save(copy)
            state = copy
            isSaving = false
            return true
        } catch {
            presentedError = AppMessage(title: "Couldn’t \(action)", message: error.localizedDescription)
            isSaving = false
            return false
        }
    }

    @discardableResult
    func addStudent(name: String, gradeLevel: String) -> Bool {
        update("add student") { state in
            _ = try state.addStudent(name: name, gradeLevel: gradeLevel)
        }
    }

    @discardableResult
    func addCourse(title: String, studentIDs: [UUID], lessonTitles: [String], startDay: String?, weekdays: Set<Int>) -> Bool {
        update("create lesson sequence") { state in
            _ = try state.addCourse(
                title: title,
                studentIDs: studentIDs,
                lessonTitles: lessonTitles,
                startDay: startDay,
                weekdays: weekdays
            )
        }
    }

    @discardableResult
    func setStatus(_ assignment: Assignment, status: AssignmentStatus, completedDay: String?) -> Bool {
        update("update lesson") { state in
            try state.setAssignmentStatus(id: assignment.id, status: status, completedDay: completedDay)
        }
    }

    @discardableResult
    func toggleAssignmentStatus(_ assignment: Assignment) -> Bool {
        let newStatus: AssignmentStatus = assignment.status == .completed ? .planned : .completed
        let completedDay = newStatus == .completed ? SchoolDate.today : nil
        return setStatus(assignment, status: newStatus, completedDay: completedDay)
    }

    @discardableResult
    func rescheduleAssignment(_ assignment: Assignment, to day: String?) -> Bool {
        update("reschedule lesson") { state in
            try state.rescheduleAssignment(id: assignment.id, newDay: day)
        }
    }

    @discardableResult
    func rescheduleOverdue(to targetDay: String, studentID: UUID? = nil) -> Bool {
        update("reschedule overdue lessons") { state in
            _ = try state.rescheduleOverdueAssignments(to: targetDay, studentID: studentID)
        }
    }

    func overdueAssignments(asOf day: String = SchoolDate.today, studentID: UUID? = nil) -> [Assignment] {
        state.assignments.filter { assignment in
            if let studentID, assignment.studentID != studentID { return false }
            guard let scheduledDay = assignment.scheduledDay else { return false }
            return scheduledDay < day && assignment.status != .completed && assignment.status != .skipped
        }
    }

    func attendanceEntry(for studentID: UUID, day: String = SchoolDate.today) -> AttendanceEntry? {
        state.attendance.first { $0.studentID == studentID && $0.day == day }
    }

    @discardableResult
    func confirmAttendance(studentID: UUID, day: String, minutes: Int) -> Bool {
        update("record attendance") { state in
            try state.confirmAttendance(studentID: studentID, day: day, minutes: minutes)
        }
    }

    @discardableResult
    func logActivity(title: String, studentIDs: [UUID], day: String, minutes: Int) -> Bool {
        update("log activity") { state in
            try state.logActivity(title: title, studentIDs: studentIDs, day: day, minutes: minutes)
        }
    }

    func student(for id: UUID) -> Student? { state.students.first { $0.id == id } }
    func lesson(for id: UUID) -> Lesson? { state.lessons.first { $0.id == id } }
    func course(for lesson: Lesson) -> Course? { state.courses.first { $0.id == lesson.courseID } }

    static func defaultFileURL() -> URL {
        #if DEBUG
        // UI tests get their own persistent household; relaunch never resets it.
        if let rawID = ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"],
           let id = UUID(uuidString: rawID) {
            return URL.applicationSupportDirectory
                .appendingPathComponent("HomeSchoolHelperUITests", isDirectory: true)
                .appendingPathComponent(id.uuidString, isDirectory: true)
                .appendingPathComponent("school-state.json")
        }
        #endif
        return URL.applicationSupportDirectory
            .appendingPathComponent("HomeSchoolHelper", isDirectory: true)
            .appendingPathComponent("school-state.json")
    }
}

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum SchoolDate {
    static func string(_ date: Date) -> String { SchoolDay.string(from: date) }

    static func date(_ day: String?) -> Date? {
        guard let day else { return nil }
        return try? SchoolDay.date(from: day)
    }

    static var today: String { string(Date()) }

    static func short(_ day: String?) -> String {
        guard let value = date(day) else { return "Flexible" }
        return value.formatted(.dateTime.month(.abbreviated).day())
    }

    static func long(_ day: String) -> String {
        guard let value = date(day) else { return day }
        return value.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
