import Foundation

public enum AssignmentStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress
    case completed
    case skipped
}

public struct Student: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var gradeLevel: String

    public init(id: UUID = UUID(), name: String, gradeLevel: String) {
        self.id = id
        self.name = name
        self.gradeLevel = gradeLevel
    }
}

public struct Course: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String

    public init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

public struct Lesson: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var courseID: UUID
    public var title: String
    public var sequence: Int

    public init(id: UUID = UUID(), courseID: UUID, title: String, sequence: Int) {
        self.id = id
        self.courseID = courseID
        self.title = title
        self.sequence = sequence
    }
}

public struct Assignment: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var studentID: UUID
    public var lessonID: UUID
    public var scheduledDay: String?
    public var status: AssignmentStatus
    public var completedDay: String?

    public init(
        id: UUID = UUID(),
        studentID: UUID,
        lessonID: UUID,
        scheduledDay: String? = nil,
        status: AssignmentStatus = .planned,
        completedDay: String? = nil
    ) {
        self.id = id
        self.studentID = studentID
        self.lessonID = lessonID
        self.scheduledDay = scheduledDay
        self.status = status
        self.completedDay = completedDay
    }
}

public struct AttendanceEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var studentID: UUID
    public var day: String
    public var minutes: Int

    public init(id: UUID = UUID(), studentID: UUID, day: String, minutes: Int) {
        self.id = id
        self.studentID = studentID
        self.day = day
        self.minutes = minutes
    }
}

public struct LearningActivity: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var studentID: UUID
    public var title: String
    public var day: String
    public var minutes: Int

    public init(id: UUID = UUID(), studentID: UUID, title: String, day: String, minutes: Int) {
        self.id = id
        self.studentID = studentID
        self.title = title
        self.day = day
        self.minutes = minutes
    }
}

public enum SchoolStateError: LocalizedError, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidValue(String)
    case unknownStudent(UUID)
    case unknownAssignment(UUID)
    case invalidDate(String)
    case invalidMinutes(Int, allowed: ClosedRange<Int>)
    case duplicateID(String)
    case duplicateAttendance(UUID, String)
    case danglingReference(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "This data uses unsupported schema version \(version). Update the app or restore data created by a compatible version."
        case .invalidValue(let message):
            return message
        case .unknownStudent:
            return "One or more selected students no longer exist. Refresh the household and try again."
        case .unknownAssignment:
            return "That assignment no longer exists. Refresh the plan and try again."
        case .invalidDate(let value):
            return "\"\(value)\" is not a valid Gregorian date. Use YYYY-MM-DD."
        case .invalidMinutes(let minutes, let allowed):
            return "\(minutes) minutes is outside the allowed range \(allowed.lowerBound)...\(allowed.upperBound). Correct the duration and try again."
        case .duplicateID(let collection):
            return "The \(collection) list contains duplicate IDs. Restore or edit the data so every record has a unique ID."
        case .duplicateAttendance:
            return "There is more than one attendance record for this student and day. Keep one record, then try again."
        case .danglingReference(let message):
            return "\(message) Restore the missing record or remove the invalid reference."
        }
    }
}

public struct SchoolState: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var students: [Student]
    public var courses: [Course]
    public var lessons: [Lesson]
    public var assignments: [Assignment]
    public var attendance: [AttendanceEntry]
    public var activities: [LearningActivity]

    public init(
        schemaVersion: Int = 1,
        students: [Student] = [],
        courses: [Course] = [],
        lessons: [Lesson] = [],
        assignments: [Assignment] = [],
        attendance: [AttendanceEntry] = [],
        activities: [LearningActivity] = []
    ) {
        self.schemaVersion = schemaVersion
        self.students = students
        self.courses = courses
        self.lessons = lessons
        self.assignments = assignments
        self.attendance = attendance
        self.activities = activities
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw SchoolStateError.unsupportedSchema(schemaVersion) }

        try validateUniqueIDs(students.map(\.id), collection: "students")
        try validateUniqueIDs(courses.map(\.id), collection: "courses")
        try validateUniqueIDs(lessons.map(\.id), collection: "lessons")
        try validateUniqueIDs(assignments.map(\.id), collection: "assignments")
        try validateUniqueIDs(attendance.map(\.id), collection: "attendance")
        try validateUniqueIDs(activities.map(\.id), collection: "activities")

        let studentIDs = Set(students.map(\.id))
        let courseIDs = Set(courses.map(\.id))
        let lessonIDs = Set(lessons.map(\.id))
        let lessonCounts = Dictionary(grouping: lessons, by: \.courseID).mapValues(\.count)

        for student in students {
            try validateRequiredText(student.name, field: "Student name")
            try validateRequiredText(student.gradeLevel, field: "Grade level")
        }
        for course in courses {
            try validateRequiredText(course.title, field: "Course title")
            guard lessonCounts[course.id, default: 0] <= 365 else {
                throw SchoolStateError.invalidValue("A course may contain at most 365 lessons.")
            }
        }
        for lesson in lessons {
            guard courseIDs.contains(lesson.courseID) else {
                throw SchoolStateError.danglingReference("A lesson refers to a missing course")
            }
            try validateRequiredText(lesson.title, field: "Lesson title")
            guard lesson.sequence > 0 else {
                throw SchoolStateError.invalidValue("Lesson sequence must be positive.")
            }
        }
        for assignment in assignments {
            guard studentIDs.contains(assignment.studentID) else {
                throw SchoolStateError.danglingReference("An assignment refers to a missing student")
            }
            guard lessonIDs.contains(assignment.lessonID) else {
                throw SchoolStateError.danglingReference("An assignment refers to a missing lesson")
            }
            if let scheduledDay = assignment.scheduledDay {
                try validateDay(scheduledDay)
            }
            switch assignment.status {
            case .completed:
                guard let completedDay = assignment.completedDay else {
                    throw SchoolStateError.invalidValue("Completed assignments require a completion day.")
                }
                try validateDay(completedDay)
            case .planned, .inProgress, .skipped:
                guard assignment.completedDay == nil else {
                    throw SchoolStateError.invalidValue("Only completed assignments may have a completion day.")
                }
            }
        }

        var attendanceKeys = Set<AttendanceKey>()
        for entry in attendance {
            guard studentIDs.contains(entry.studentID) else {
                throw SchoolStateError.danglingReference("An attendance entry refers to a missing student")
            }
            try validateDay(entry.day)
            try validateMinutes(entry.minutes, allowed: 1...1440)
            let key = AttendanceKey(studentID: entry.studentID, day: entry.day)
            guard attendanceKeys.insert(key).inserted else {
                throw SchoolStateError.duplicateAttendance(entry.studentID, entry.day)
            }
        }
        for activity in activities {
            guard studentIDs.contains(activity.studentID) else {
                throw SchoolStateError.danglingReference("An activity refers to a missing student")
            }
            try validateRequiredText(activity.title, field: "Activity title")
            try validateDay(activity.day)
            try validateMinutes(activity.minutes, allowed: 0...1440)
        }
    }

    @discardableResult
    public mutating func addStudent(name: String, gradeLevel: String) throws -> UUID {
        try validate()
        let cleanedName = try cleanedRequiredText(name, field: "Student name")
        let cleanedGradeLevel = try cleanedRequiredText(gradeLevel, field: "Grade level")
        let student = Student(name: cleanedName, gradeLevel: cleanedGradeLevel)
        students.append(student)
        return student.id
    }

    @discardableResult
    public mutating func addCourse(
        title: String,
        studentIDs: [UUID],
        lessonTitles: [String],
        startDay: String?,
        weekdays: Set<Int> = [2, 3, 4, 5, 6]
    ) throws -> UUID {
        try validate()
        let cleanedTitle = try cleanedRequiredText(title, field: "Course title")
        guard lessonTitles.count <= 365 else {
            throw SchoolStateError.invalidValue("A course may contain at most 365 lessons.")
        }
        let cleanedLessonTitles = try lessonTitles.map { try cleanedRequiredText($0, field: "Lesson title") }
        let selectedStudents = unique(studentIDs)
        guard !selectedStudents.isEmpty else {
            throw SchoolStateError.invalidValue("Select at least one student before creating a course.")
        }
        guard !cleanedLessonTitles.isEmpty else {
            throw SchoolStateError.invalidValue("Add at least one lesson before creating a course.")
        }
        let knownStudents = Set(students.map(\.id))
        for studentID in selectedStudents where !knownStudents.contains(studentID) {
            throw SchoolStateError.unknownStudent(studentID)
        }

        var scheduledDays: [String?] = Array(repeating: nil, count: cleanedLessonTitles.count)
        if let startDay {
            try validateDay(startDay)
            guard !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }) else {
                throw SchoolStateError.invalidValue("Dated scheduling requires one or more weekdays numbered 1 through 7.")
            }
            scheduledDays = try scheduledDaysFrom(startDay: startDay, count: cleanedLessonTitles.count, weekdays: weekdays)
        }

        let course = Course(title: cleanedTitle)
        let newLessons = cleanedLessonTitles.enumerated().map {
            Lesson(courseID: course.id, title: $0.element, sequence: $0.offset + 1)
        }
        var newAssignments: [Assignment] = []
        newAssignments.reserveCapacity(selectedStudents.count * newLessons.count)
        for studentID in selectedStudents {
            for (index, lesson) in newLessons.enumerated() {
                newAssignments.append(Assignment(studentID: studentID, lessonID: lesson.id, scheduledDay: scheduledDays[index]))
            }
        }

        courses.append(course)
        lessons.append(contentsOf: newLessons)
        assignments.append(contentsOf: newAssignments)
        return course.id
    }

    public mutating func setAssignmentStatus(
        id: UUID,
        status: AssignmentStatus,
        completedDay: String?
    ) throws {
        try validate()
        guard let assignmentIndex = assignments.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAssignment(id)
        }
        let normalizedCompletedDay: String?
        if status == .completed {
            guard let completedDay else {
                throw SchoolStateError.invalidValue("Completed assignments require a completion day.")
            }
            try validateDay(completedDay)
            normalizedCompletedDay = completedDay
        } else {
            normalizedCompletedDay = nil
        }
        assignments[assignmentIndex].status = status
        assignments[assignmentIndex].completedDay = normalizedCompletedDay
    }

    public mutating func rescheduleAssignment(id: UUID, newDay: String?) throws {
        try validate()
        guard let assignmentIndex = assignments.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAssignment(id)
        }
        if let newDay {
            try validateDay(newDay)
        }
        assignments[assignmentIndex].scheduledDay = newDay
    }

    @discardableResult
    public mutating func rescheduleOverdueAssignments(to targetDay: String, studentID: UUID? = nil) throws -> Int {
        try validate()
        try validateDay(targetDay)
        var count = 0
        for index in assignments.indices {
            let assignment = assignments[index]
            if let studentID, assignment.studentID != studentID {
                continue
            }
            if let scheduledDay = assignment.scheduledDay,
               scheduledDay < targetDay,
               assignment.status != .completed && assignment.status != .skipped {
                assignments[index].scheduledDay = targetDay
                count += 1
            }
        }
        return count
    }

    public mutating func confirmAttendance(studentID: UUID, day: String, minutes: Int) throws {
        try validate()
        guard students.contains(where: { $0.id == studentID }) else {
            throw SchoolStateError.unknownStudent(studentID)
        }
        try validateDay(day)
        try validateMinutes(minutes, allowed: 1...1440)

        if let index = attendance.firstIndex(where: { $0.studentID == studentID && $0.day == day }) {
            attendance[index].minutes = minutes
        } else {
            attendance.append(AttendanceEntry(studentID: studentID, day: day, minutes: minutes))
        }
    }

    public mutating func logActivity(title: String, studentIDs: [UUID], day: String, minutes: Int) throws {
        try validate()
        let cleanedTitle = try cleanedRequiredText(title, field: "Activity title")
        let selectedStudents = unique(studentIDs)
        guard !selectedStudents.isEmpty else {
            throw SchoolStateError.invalidValue("Select at least one student before logging an activity.")
        }
        let knownStudents = Set(students.map(\.id))
        for studentID in selectedStudents where !knownStudents.contains(studentID) {
            throw SchoolStateError.unknownStudent(studentID)
        }
        try validateDay(day)
        try validateMinutes(minutes, allowed: 0...1440)

        activities.append(contentsOf: selectedStudents.map {
            LearningActivity(studentID: $0, title: cleanedTitle, day: day, minutes: minutes)
        })
    }
}

public enum SchoolDay {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = Locale(identifier: "en_US_POSIX")
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func date(from string: String) throws -> Date {
        guard isValid(string) else { throw SchoolStateError.invalidDate(string) }
        let values = string.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2])) else {
            throw SchoolStateError.invalidDate(string)
        }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == values[0], components.month == values[1], components.day == values[2] else {
            throw SchoolStateError.invalidDate(string)
        }
        return date
    }

    public static func isValid(_ string: String) -> Bool {
        guard string.utf8.count == 10 else { return false }
        let bytes = Array(string.utf8)
        guard bytes[4] == 45, bytes[7] == 45 else { return false }
        guard bytes.enumerated().allSatisfy({ index, byte in
            index == 4 || index == 7 || (48...57).contains(byte)
        }) else { return false }
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...9999).contains(year) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return false }
        let normalized = calendar.dateComponents([.year, .month, .day], from: date)
        return normalized.year == year && normalized.month == month && normalized.day == day
    }
}

public protocol SchoolRepository {
    func load() throws -> SchoolState
    func save(_ state: SchoolState) throws
}

public enum SchoolRepositoryError: LocalizedError, Sendable {
    case couldNotRead(URL, underlying: String)
    case couldNotDecode(URL, underlying: String)
    case couldNotSave(URL, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .couldNotRead(let url, _):
            return "Could not read school data at \(url.path). Check the file and try again; it has not been replaced."
        case .couldNotDecode(let url, _):
            return "School data at \(url.path) is not valid. Restore a backup or repair the file; it has not been replaced."
        case .couldNotSave(let url, _):
            return "Could not save school data at \(url.path). Check available storage and try again."
        }
    }
}

public final class JSONSchoolRepository: SchoolRepository {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> SchoolState {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain,
               [CocoaError.Code.fileNoSuchFile.rawValue,
                CocoaError.Code.fileReadNoSuchFile.rawValue].contains(nsError.code) {
                return SchoolState()
            }
            throw SchoolRepositoryError.couldNotRead(fileURL, underlying: error.localizedDescription)
        }
        let state: SchoolState
        do {
            state = try JSONDecoder().decode(SchoolState.self, from: data)
        } catch {
            throw SchoolRepositoryError.couldNotDecode(fileURL, underlying: error.localizedDescription)
        }
        try state.validate()
        return state
    }

    public func save(_ state: SchoolState) throws {
        try state.validate()
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            data = try encoder.encode(state)
        } catch {
            throw SchoolRepositoryError.couldNotSave(fileURL, underlying: error.localizedDescription)
        }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw SchoolRepositoryError.couldNotSave(fileURL, underlying: error.localizedDescription)
        }
    }
}

private struct AttendanceKey: Hashable {
    let studentID: UUID
    let day: String
}

private func validateUniqueIDs(_ ids: [UUID], collection: String) throws {
    guard Set(ids).count == ids.count else { throw SchoolStateError.duplicateID(collection) }
}

private func validateRequiredText(_ value: String, field: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SchoolStateError.invalidValue("\(field) cannot be empty.")
    }
}

private func cleanedRequiredText(_ value: String, field: String) throws -> String {
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    try validateRequiredText(cleaned, field: field)
    return cleaned
}

private func validateDay(_ value: String) throws {
    guard SchoolDay.isValid(value) else { throw SchoolStateError.invalidDate(value) }
}

private func validateMinutes(_ value: Int, allowed: ClosedRange<Int>) throws {
    guard allowed.contains(value) else { throw SchoolStateError.invalidMinutes(value, allowed: allowed) }
}

private func unique(_ values: [UUID]) -> [UUID] {
    var seen = Set<UUID>()
    return values.filter { seen.insert($0).inserted }
}

private func scheduledDaysFrom(startDay: String, count: Int, weekdays: Set<Int>) throws -> [String?] {
    guard count > 0 else { return [] }
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let values = startDay.split(separator: "-").compactMap { Int($0) }
    guard values.count == 3,
          let initialDate = calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2])) else {
        throw SchoolStateError.invalidDate(startDay)
    }
    var date = initialDate
    var result: [String?] = []
    result.reserveCapacity(count)
    while result.count < count {
        if weekdays.contains(calendar.component(.weekday, from: date)) {
            result.append(SchoolDay.string(from: date, calendar: calendar))
        }
        if result.count == count { break }
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
            throw SchoolStateError.invalidDate(startDay)
        }
        let nextYear = calendar.component(.year, from: nextDate)
        guard (1...9999).contains(nextYear) else {
            throw SchoolStateError.invalidDate(startDay)
        }
        date = nextDate
    }
    return result
}
