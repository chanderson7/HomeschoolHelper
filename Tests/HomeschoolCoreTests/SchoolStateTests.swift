import XCTest
@testable import HomeschoolCore

final class SchoolStateTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeschoolCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try super.tearDownWithError()
    }

    func testSharedCourseSupportsIndependentCompletionAttendanceActivityAndReload() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: " Alice ", gradeLevel: "4")
        let ben = try state.addStudent(name: "Ben", gradeLevel: "5")
        let courseID = try state.addCourse(
            title: "Math",
            studentIDs: [alice, ben, alice],
            lessonTitles: ["Fractions", "Decimals"],
            startDay: nil
        )

        let lessons = state.lessons.filter { $0.courseID == courseID }.sorted { $0.sequence < $1.sequence }
        XCTAssertEqual(lessons.map(\.title), ["Fractions", "Decimals"])
        XCTAssertEqual(state.assignments.filter { $0.studentID == alice }.count, 2)
        XCTAssertEqual(state.assignments.filter { $0.studentID == ben }.count, 2)

        let aliceAssignment = try XCTUnwrap(state.assignments.first { $0.studentID == alice && $0.lessonID == lessons[0].id })
        let benAssignment = try XCTUnwrap(state.assignments.first { $0.studentID == ben && $0.lessonID == lessons[0].id })
        try state.setAssignmentStatus(id: aliceAssignment.id, status: .completed, completedDay: "2024-04-05")
        XCTAssertEqual(state.assignments.first { $0.id == aliceAssignment.id }?.status, .completed)
        XCTAssertEqual(state.assignments.first { $0.id == aliceAssignment.id }?.completedDay, "2024-04-05")
        XCTAssertEqual(state.assignments.first { $0.id == benAssignment.id }?.status, .planned)
        XCTAssertNil(state.assignments.first { $0.id == benAssignment.id }?.completedDay)

        try state.confirmAttendance(studentID: alice, day: "2024-04-05", minutes: 45)
        try state.logActivity(title: "Kitchen science", studentIDs: [alice, ben, alice], day: "2024-04-06", minutes: 30)
        XCTAssertEqual(state.attendance.count, 1)
        XCTAssertEqual(state.attendance[0].studentID, alice)
        XCTAssertEqual(state.attendance[0].minutes, 45)
        XCTAssertEqual(state.activities.count, 2)
        XCTAssertEqual(Set(state.activities.map(\.studentID)), Set([alice, ben]))
        XCTAssertTrue(state.activities.allSatisfy { $0.title == "Kitchen science" && $0.day == "2024-04-06" && $0.minutes == 30 })

        let repository = JSONSchoolRepository(fileURL: temporaryDirectory.appendingPathComponent("state.json"))
        try repository.save(state)
        let reloaded = try repository.load()
        XCTAssertEqual(reloaded, state)
    }

    func testRescheduleAssignmentAndOverdueAssignments() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "3")
        _ = try state.addCourse(
            title: "Reading",
            studentIDs: [alice],
            lessonTitles: ["L1", "L2", "L3"],
            startDay: "2024-04-01",
            weekdays: [2, 3, 4, 5, 6]
        )
        let assignments = state.assignments.filter { $0.studentID == alice }
        XCTAssertEqual(assignments.count, 3)

        // Reschedule single assignment to another day or flexible
        try state.rescheduleAssignment(id: assignments[0].id, newDay: "2024-04-10")
        XCTAssertEqual(state.assignments.first { $0.id == assignments[0].id }?.scheduledDay, "2024-04-10")

        try state.rescheduleAssignment(id: assignments[0].id, newDay: nil)
        XCTAssertNil(state.assignments.first { $0.id == assignments[0].id }?.scheduledDay)

        // Mark L2 completed on 2024-04-02
        try state.setAssignmentStatus(id: assignments[1].id, status: .completed, completedDay: "2024-04-02")

        // Reschedule overdue (assignments before 2024-04-05) to 2024-04-05
        // L3 is scheduled for 2024-04-03 and is uncompleted. L2 is completed so it should NOT be moved.
        let movedCount = try state.rescheduleOverdueAssignments(to: "2024-04-05", studentID: alice)
        XCTAssertEqual(movedCount, 1)
        XCTAssertEqual(state.assignments.first { $0.id == assignments[2].id }?.scheduledDay, "2024-04-05")
        XCTAssertEqual(state.assignments.first { $0.id == assignments[1].id }?.scheduledDay, "2024-04-02")
    }

    func testMissingRepositoryFileLoadsEmptyState() throws {
        let repository = JSONSchoolRepository(fileURL: temporaryDirectory.appendingPathComponent("missing.json"))
        let state = try repository.load()
        XCTAssertEqual(state, SchoolState())
    }

    func testInvalidSavePreservesPreviouslySavedHousehold() throws {
        let file = temporaryDirectory.appendingPathComponent("nested/state.json")
        let repository = JSONSchoolRepository(fileURL: file)
        var state = SchoolState()
        _ = try state.addStudent(name: "Saved learner", gradeLevel: "4")
        try repository.save(state)
        let before = try Data(contentsOf: file)
        var invalid = state
        invalid.students.append(state.students[0])
        XCTAssertThrowsError(try repository.save(invalid))
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(try repository.load(), state)
    }

    func testUnreadableDataLocationDoesNotLoadAsEmptyHousehold() throws {
        // A directory is present but cannot be decoded/read as a regular JSON file.
        let repository = JSONSchoolRepository(fileURL: temporaryDirectory)
        XCTAssertThrowsError(try repository.load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryDirectory.path))
    }

    func testSchoolDayValidatesGregorianDatesAndLeapDay() throws {
        XCTAssertTrue(SchoolDay.isValid("2024-02-29"))
        XCTAssertFalse(SchoolDay.isValid("2023-02-29"))
        XCTAssertFalse(SchoolDay.isValid("2024-04-31"))
        XCTAssertFalse(SchoolDay.isValid("2024-2-09"))
        XCTAssertFalse(SchoolDay.isValid("2024-01-01T00:00:00Z"))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let leapDay = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        XCTAssertEqual(SchoolDay.string(from: leapDay, calendar: calendar), "2024-02-29")
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = calendar.timeZone
        XCTAssertEqual(SchoolDay.string(from: leapDay, calendar: buddhistCalendar), "2024-02-29")
        XCTAssertTrue(SchoolDay.isValid("2024-02-29"))
        XCTAssertNoThrow(try SchoolDay.date(from: "2024-02-29"))
        XCTAssertThrowsError(try SchoolDay.date(from: "2023-02-29"))
    }

    func testDatedSchedulingUsesInclusiveEligibleGregorianWeekdays() throws {
        var state = SchoolState()
        let student = try state.addStudent(name: "Student", gradeLevel: "3")
        let courseID = try state.addCourse(
            title: "Writing",
            studentIDs: [student],
            lessonTitles: ["One", "Two", "Three", "Four"],
            startDay: "2024-04-01", // Monday
            weekdays: [2, 4] // Monday and Wednesday
        )

        let lessonIDs = Set(state.lessons.filter { $0.courseID == courseID }.map(\.id))
        let assignments = state.assignments
            .filter { $0.studentID == student && lessonIDs.contains($0.lessonID) }
            .sorted { $0.scheduledDay ?? "" < $1.scheduledDay ?? "" }
        XCTAssertEqual(assignments.map(\.scheduledDay), ["2024-04-01", "2024-04-03", "2024-04-08", "2024-04-10"])
    }

    func testUndatedCourseLeavesAssignmentsUndated() throws {
        var state = SchoolState()
        let student = try state.addStudent(name: "Student", gradeLevel: "3")
        _ = try state.addCourse(title: "Reading", studentIDs: [student], lessonTitles: ["A", "B", "C"], startDay: nil)
        XCTAssertEqual(state.assignments.count, 3)
        XCTAssertTrue(state.assignments.allSatisfy { $0.scheduledDay == nil })
    }

    func testInvalidMutationsLeaveStateUnchanged() throws {
        var state = SchoolState()
        let student = try state.addStudent(name: "Student", gradeLevel: "3")
        let courseID = try state.addCourse(title: "Reading", studentIDs: [student], lessonTitles: ["A"], startDay: nil)
        let assignment = try XCTUnwrap(state.assignments.first)

        let beforeUnknownStudent = state
        XCTAssertThrowsError(try state.addCourse(title: "Invalid", studentIDs: [UUID()], lessonTitles: ["X"], startDay: nil))
        XCTAssertEqual(state, beforeUnknownStudent)

        let beforeBadCompletion = state
        XCTAssertThrowsError(try state.setAssignmentStatus(id: assignment.id, status: .completed, completedDay: "2024-02-30"))
        XCTAssertEqual(state, beforeBadCompletion)

        let beforeBadAttendance = state
        XCTAssertThrowsError(try state.confirmAttendance(studentID: student, day: "2024-01-01", minutes: 0))
        XCTAssertEqual(state, beforeBadAttendance)

        let beforeBadActivity = state
        XCTAssertThrowsError(try state.logActivity(title: "Activity", studentIDs: [student, UUID()], day: "2024-01-01", minutes: 20))
        XCTAssertEqual(state, beforeBadActivity)
        XCTAssertEqual(state.lessons.first?.courseID, courseID)
    }

    func testCourseRequiresStudentsAndLessonsAndSchedulingCannotOverflowDateRange() throws {
        var state = SchoolState()
        let student = try state.addStudent(name: "Student", gradeLevel: "3")

        let beforeNoStudents = state
        XCTAssertThrowsError(try state.addCourse(title: "Empty", studentIDs: [], lessonTitles: ["A"], startDay: nil))
        XCTAssertEqual(state, beforeNoStudents)

        let beforeNoLessons = state
        XCTAssertThrowsError(try state.addCourse(title: "Empty", studentIDs: [student], lessonTitles: [], startDay: nil))
        XCTAssertEqual(state, beforeNoLessons)

        let beforeNoActivityStudents = state
        XCTAssertThrowsError(try state.logActivity(title: "Empty", studentIDs: [], day: "2024-01-01", minutes: 10))
        XCTAssertEqual(state, beforeNoActivityStudents)

        let beforeOverflow = state
        XCTAssertThrowsError(try state.addCourse(
            title: "End of calendar",
            studentIDs: [student],
            lessonTitles: ["Last day", "Beyond last day"],
            startDay: "9999-12-31"
        ))
        XCTAssertEqual(state, beforeOverflow)
    }

    func testNonCompletedStatusClearsCompletionAndDoesNotCreateAttendance() throws {
        var state = SchoolState()
        let student = try state.addStudent(name: "Student", gradeLevel: "3")
        _ = try state.addCourse(title: "Reading", studentIDs: [student], lessonTitles: ["A"], startDay: nil)
        let assignment = try XCTUnwrap(state.assignments.first)

        try state.setAssignmentStatus(id: assignment.id, status: .completed, completedDay: "2024-01-05")
        try state.setAssignmentStatus(id: assignment.id, status: .skipped, completedDay: "2024-01-06")
        XCTAssertEqual(state.assignments.first?.status, .skipped)
        XCTAssertNil(state.assignments.first?.completedDay)
        XCTAssertTrue(state.attendance.isEmpty)

        try state.setAssignmentStatus(id: assignment.id, status: .inProgress, completedDay: "2024-01-07")
        XCTAssertEqual(state.assignments.first?.status, .inProgress)
        XCTAssertNil(state.assignments.first?.completedDay)
        XCTAssertTrue(state.attendance.isEmpty)
    }

    func testAttendanceConfirmationUpsertsOneStudentDayRecord() throws {
        var state = SchoolState()
        let student = try state.addStudent(name: "Student", gradeLevel: "3")
        try state.confirmAttendance(studentID: student, day: "2024-01-08", minutes: 20)
        try state.confirmAttendance(studentID: student, day: "2024-01-08", minutes: 75)
        XCTAssertEqual(state.attendance.count, 1)
        XCTAssertEqual(state.attendance.first?.minutes, 75)
    }

    func testUnsupportedSchemaAndCorruptFileAreThrownWithoutOverwritingFile() throws {
        let fileURL = temporaryDirectory.appendingPathComponent("state.json")
        let repository = JSONSchoolRepository(fileURL: fileURL)
        var state = SchoolState()
        _ = try state.addStudent(name: "Saved", gradeLevel: "2")
        try repository.save(state)

        let unsupported = Data(#"{"schemaVersion":999,"students":[],"courses":[],"lessons":[],"assignments":[],"attendance":[],"activities":[]}"#.utf8)
        try unsupported.write(to: fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: fileURL), unsupported)

        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: fileURL), corrupt)
    }

    func testValidationRejectsMalformedStateRecords() throws {
        let studentID = UUID()
        let courseID = UUID()
        let lessonID = UUID()
        let assignmentID = UUID()
        let student = Student(id: studentID, name: "One", gradeLevel: "1")
        let course = Course(id: courseID, title: "Math")
        let lesson = Lesson(id: lessonID, courseID: courseID, title: "Lesson", sequence: 1)
        let assignment = Assignment(id: assignmentID, studentID: studentID, lessonID: lessonID, scheduledDay: nil, status: .planned, completedDay: nil)
        let attendance = AttendanceEntry(id: UUID(), studentID: studentID, day: "2024-01-01", minutes: 10)
        let activity = LearningActivity(id: UUID(), studentID: studentID, title: "Read", day: "2024-01-01", minutes: 10)

        func validState() -> SchoolState {
            SchoolState(
                schemaVersion: 1,
                students: [student],
                courses: [course],
                lessons: [lesson],
                assignments: [assignment],
                attendance: [attendance],
                activities: [activity]
            )
        }

        var duplicateIDs = validState()
        duplicateIDs.students.append(student)
        XCTAssertThrowsError(try duplicateIDs.validate())

        var danglingCourse = validState()
        danglingCourse.lessons = [Lesson(id: lessonID, courseID: UUID(), title: "Lesson", sequence: 1)]
        XCTAssertThrowsError(try danglingCourse.validate())

        var danglingAssignment = validState()
        danglingAssignment.assignments = [Assignment(id: assignmentID, studentID: studentID, lessonID: UUID(), scheduledDay: nil, status: .planned, completedDay: nil)]
        XCTAssertThrowsError(try danglingAssignment.validate())

        var duplicateAttendance = validState()
        duplicateAttendance.attendance.append(AttendanceEntry(id: UUID(), studentID: studentID, day: "2024-01-01", minutes: 20))
        XCTAssertThrowsError(try duplicateAttendance.validate())

        var invalidMinutes = validState()
        invalidMinutes.activities = [LearningActivity(id: activity.id, studentID: studentID, title: "Read", day: "2024-01-01", minutes: 1441)]
        XCTAssertThrowsError(try invalidMinutes.validate())

        var blankTitle = validState()
        blankTitle.courses = [Course(id: courseID, title: " ")]
        XCTAssertThrowsError(try blankTitle.validate())

        var invalidSequence = validState()
        invalidSequence.lessons = [Lesson(id: lessonID, courseID: courseID, title: "Lesson", sequence: 0)]
        XCTAssertThrowsError(try invalidSequence.validate())

        var inconsistentCompletion = validState()
        inconsistentCompletion.assignments = [Assignment(id: assignmentID, studentID: studentID, lessonID: lessonID, scheduledDay: nil, status: .completed, completedDay: nil)]
        XCTAssertThrowsError(try inconsistentCompletion.validate())

        var staleCompletionDay = validState()
        staleCompletionDay.assignments = [Assignment(id: assignmentID, studentID: studentID, lessonID: lessonID, scheduledDay: nil, status: .planned, completedDay: "2024-01-01")]
        XCTAssertThrowsError(try staleCompletionDay.validate())
    }
}
