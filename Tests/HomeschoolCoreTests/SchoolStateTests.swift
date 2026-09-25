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

    func testStudentUpdateAndCascadeDelete() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "3")
        let ben = try state.addStudent(name: "Ben", gradeLevel: "5")
        let courseID = try state.addCourse(
            title: "Science",
            studentIDs: [alice, ben],
            lessonTitles: ["Planets", "Stars"],
            startDay: nil
        )
        try state.confirmAttendance(studentID: alice, day: "2024-05-01", minutes: 60)
        try state.confirmAttendance(studentID: ben, day: "2024-05-01", minutes: 60)
        try state.logActivity(title: "Museum", studentIDs: [alice, ben], day: "2024-05-02", minutes: 90)

        // Update Alice's name and grade
        try state.updateStudent(id: alice, name: "Alice M.", gradeLevel: "4")
        XCTAssertEqual(state.students.first { $0.id == alice }?.name, "Alice M.")
        XCTAssertEqual(state.students.first { $0.id == alice }?.gradeLevel, "4")

        // Reject invalid updates
        XCTAssertThrowsError(try state.updateStudent(id: alice, name: " ", gradeLevel: "4"))
        XCTAssertThrowsError(try state.updateStudent(id: UUID(), name: "Ghost", gradeLevel: "1"))

        // Delete Alice: should cascade-delete her assignments, attendance, activities
        try state.deleteStudent(id: alice)
        XCTAssertFalse(state.students.contains { $0.id == alice })
        XCTAssertTrue(state.students.contains { $0.id == ben })
        XCTAssertTrue(state.assignments.allSatisfy { $0.studentID != alice })
        XCTAssertEqual(state.assignments.filter { $0.studentID == ben }.count, 2)
        XCTAssertTrue(state.attendance.allSatisfy { $0.studentID != alice })
        XCTAssertEqual(state.attendance.count, 1)
        XCTAssertTrue(state.activities.allSatisfy { $0.studentID != alice })
        XCTAssertEqual(state.activities.count, 1)

        // Deleting non-existent student throws
        XCTAssertThrowsError(try state.deleteStudent(id: alice))
        XCTAssertNoThrow(try state.validate())
    }

    func testCourseUpdateAndCascadeDelete() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "3")
        let courseID = try state.addCourse(
            title: "History",
            studentIDs: [alice],
            lessonTitles: ["Rome", "Greece"],
            startDay: nil
        )

        // Update Course Title
        try state.updateCourse(id: courseID, title: "Ancient Civilizations")
        XCTAssertEqual(state.courses.first { $0.id == courseID }?.title, "Ancient Civilizations")
        XCTAssertThrowsError(try state.updateCourse(id: courseID, title: ""))
        XCTAssertThrowsError(try state.updateCourse(id: UUID(), title: "Ghost"))

        // Delete Course: cascades to lessons and assignments
        try state.deleteCourse(id: courseID)
        XCTAssertFalse(state.courses.contains { $0.id == courseID })
        XCTAssertTrue(state.lessons.filter { $0.courseID == courseID }.isEmpty)
        XCTAssertTrue(state.assignments.isEmpty)
        XCTAssertThrowsError(try state.deleteCourse(id: courseID))
        XCTAssertNoThrow(try state.validate())
    }

    func testLessonCRUDAndReorder() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "3")
        let courseID = try state.addCourse(
            title: "Math",
            studentIDs: [alice],
            lessonTitles: ["L1", "L2", "L3"],
            startDay: nil
        )

        let initialLessons = state.lessons.filter { $0.courseID == courseID }.sorted { $0.sequence < $1.sequence }
        XCTAssertEqual(initialLessons.count, 3)

        // Update Lesson
        try state.updateLesson(id: initialLessons[0].id, title: "Fractions Basics")
        XCTAssertEqual(state.lessons.first { $0.id == initialLessons[0].id }?.title, "Fractions Basics")
        XCTAssertThrowsError(try state.updateLesson(id: initialLessons[0].id, title: "   "))
        XCTAssertThrowsError(try state.updateLesson(id: UUID(), title: "Ghost"))

        // Add Lesson to existing course
        let newLessonID = try state.addLesson(courseID: courseID, title: "L4")
        let newLesson = try XCTUnwrap(state.lessons.first { $0.id == newLessonID })
        XCTAssertEqual(newLesson.sequence, 4)
        // Alice should have an assignment created for this new lesson
        XCTAssertTrue(state.assignments.contains { $0.studentID == alice && $0.lessonID == newLessonID })

        // Delete middle lesson (L2)
        let l2ID = initialLessons[1].id
        try state.deleteLesson(id: l2ID)
        XCTAssertFalse(state.lessons.contains { $0.id == l2ID })
        XCTAssertFalse(state.assignments.contains { $0.lessonID == l2ID })

        // Check sequence re-indexing: should be 1, 2, 3
        let remainingLessons = state.lessons.filter { $0.courseID == courseID }.sorted { $0.sequence < $1.sequence }
        XCTAssertEqual(remainingLessons.count, 3)
        XCTAssertEqual(remainingLessons.map(\.sequence), [1, 2, 3])

        // Reorder lessons
        let reversedIDs = remainingLessons.reversed().map(\.id)
        try state.reorderLessons(courseID: courseID, lessonIDsInOrder: reversedIDs)
        let reorderedLessons = state.lessons.filter { $0.courseID == courseID }.sorted { $0.sequence < $1.sequence }
        XCTAssertEqual(reorderedLessons.map(\.id), reversedIDs)
        XCTAssertEqual(reorderedLessons.map(\.sequence), [1, 2, 3])

        // Invalid reorder (missing lesson or mismatch)
        XCTAssertThrowsError(try state.reorderLessons(courseID: courseID, lessonIDsInOrder: [remainingLessons[0].id]))
        XCTAssertThrowsError(try state.reorderLessons(courseID: UUID(), lessonIDsInOrder: []))
        XCTAssertNoThrow(try state.validate())
    }

    func testAttendanceUpdateAndDelete() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "3")
        try state.confirmAttendance(studentID: alice, day: "2024-05-10", minutes: 120)
        let entry = try XCTUnwrap(state.attendance.first)

        // Update attendance minutes
        try state.updateAttendance(id: entry.id, minutes: 150)
        XCTAssertEqual(state.attendance.first?.minutes, 150)

        // Update attendance day
        try state.updateAttendance(id: entry.id, day: "2024-05-11", minutes: 180)
        XCTAssertEqual(state.attendance.first?.day, "2024-05-11")
        XCTAssertEqual(state.attendance.first?.minutes, 180)

        // Prevent duplicate day for same student
        try state.confirmAttendance(studentID: alice, day: "2024-05-12", minutes: 60)
        XCTAssertThrowsError(try state.updateAttendance(id: entry.id, day: "2024-05-12", minutes: 90))

        // Delete attendance
        try state.deleteAttendance(id: entry.id)
        XCTAssertEqual(state.attendance.count, 1)
        XCTAssertFalse(state.attendance.contains { $0.id == entry.id })
        XCTAssertThrowsError(try state.deleteAttendance(id: entry.id))
        XCTAssertNoThrow(try state.validate())
    }

    func testActivityUpdateAndDelete() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "3")
        try state.logActivity(title: "Library", studentIDs: [alice], day: "2024-05-10", minutes: 45)
        let activity = try XCTUnwrap(state.activities.first)

        // Update activity
        try state.updateActivity(id: activity.id, title: "Public Library Visit", day: "2024-05-11", minutes: 60)
        let updated = try XCTUnwrap(state.activities.first)
        XCTAssertEqual(updated.title, "Public Library Visit")
        XCTAssertEqual(updated.day, "2024-05-11")
        XCTAssertEqual(updated.minutes, 60)

        // Invalid update
        XCTAssertThrowsError(try state.updateActivity(id: activity.id, title: "", day: "2024-05-11", minutes: 60))
        XCTAssertThrowsError(try state.updateActivity(id: activity.id, title: "Title", day: "bad-date", minutes: 60))
        XCTAssertThrowsError(try state.updateActivity(id: activity.id, title: "Title", day: "2024-05-11", minutes: -1))

        // Delete activity
        try state.deleteActivity(id: activity.id)
        XCTAssertTrue(state.activities.isEmpty)
        XCTAssertThrowsError(try state.deleteActivity(id: activity.id))
        XCTAssertNoThrow(try state.validate())
    }

    func testAcademicYearCRUDAndValidation() throws {
        var state = SchoolState()
        let yearID = try state.addAcademicYear(
            title: "2024–2025",
            startDay: "2024-08-01",
            endDay: "2025-06-30",
            targetDays: 180,
            targetHours: 900,
            makeActive: true
        )
        XCTAssertEqual(state.academicYears.count, 1)
        XCTAssertEqual(state.activeYearID, yearID)
        let year = try XCTUnwrap(state.academicYears.first)
        XCTAssertEqual(year.title, "2024–2025")
        XCTAssertEqual(year.targetDays, 180)
        XCTAssertEqual(year.targetHours, 900)
        XCTAssertTrue(year.contains(day: "2024-08-01"))
        XCTAssertTrue(year.contains(day: "2025-01-15"))
        XCTAssertTrue(year.contains(day: "2025-06-30"))
        XCTAssertFalse(year.contains(day: "2024-07-31"))
        XCTAssertFalse(year.contains(day: "2025-07-01"))

        // Update year
        try state.updateAcademicYear(
            id: yearID,
            title: "2024–2025 School Year",
            startDay: "2024-08-15",
            endDay: "2025-06-15",
            targetDays: 175,
            targetHours: 850
        )
        let updated = try XCTUnwrap(state.academicYears.first)
        XCTAssertEqual(updated.title, "2024–2025 School Year")
        XCTAssertEqual(updated.startDay, "2024-08-15")
        XCTAssertEqual(updated.targetDays, 175)
        XCTAssertEqual(updated.targetHours, 850)

        // Validation errors
        XCTAssertThrowsError(try state.addAcademicYear(title: "", startDay: "2025-08-01", endDay: "2026-06-30"))
        XCTAssertThrowsError(try state.addAcademicYear(title: "Year", startDay: "2025-06-30", endDay: "2025-01-01")) // start >= end
        XCTAssertThrowsError(try state.addAcademicYear(title: "Year", startDay: "bad-date", endDay: "2026-06-30"))
        XCTAssertThrowsError(try state.addAcademicYear(title: "Year", startDay: "2025-08-01", endDay: "2026-06-30", targetDays: 0))
        XCTAssertThrowsError(try state.addAcademicYear(title: "Year", startDay: "2025-08-01", endDay: "2026-06-30", targetDays: 400))
        XCTAssertThrowsError(try state.addAcademicYear(title: "Year", startDay: "2025-08-01", endDay: "2026-06-30", targetHours: 0))

        // Add second year & set active
        let year2ID = try state.addAcademicYear(
            title: "2025–2026",
            startDay: "2025-08-01",
            endDay: "2026-06-30"
        )
        try state.setActiveAcademicYear(id: year2ID)
        XCTAssertEqual(state.activeYearID, year2ID)
        try state.setActiveAcademicYear(id: nil)
        XCTAssertNil(state.activeYearID)
        XCTAssertThrowsError(try state.setActiveAcademicYear(id: UUID()))

        // Delete year
        try state.deleteAcademicYear(id: yearID)
        XCTAssertEqual(state.academicYears.count, 1)
        XCTAssertEqual(state.academicYears.first?.id, year2ID)
        XCTAssertThrowsError(try state.deleteAcademicYear(id: yearID))
    }

    func testAcademicTermCRUDAndValidation() throws {
        var state = SchoolState()
        let yearID = try state.addAcademicYear(
            title: "2024–2025",
            startDay: "2024-08-01",
            endDay: "2025-06-30"
        )
        let termID = try state.addTerm(
            yearID: yearID,
            title: "Fall Semester",
            startDay: "2024-08-01",
            endDay: "2024-12-20"
        )
        XCTAssertEqual(state.terms.count, 1)
        let term = try XCTUnwrap(state.terms.first)
        XCTAssertEqual(term.title, "Fall Semester")
        XCTAssertEqual(term.academicYearID, yearID)

        // Invalid term
        XCTAssertThrowsError(try state.addTerm(yearID: UUID(), title: "Spring", startDay: "2025-01-06", endDay: "2025-05-30"))
        XCTAssertThrowsError(try state.addTerm(yearID: yearID, title: "", startDay: "2025-01-06", endDay: "2025-05-30"))
        XCTAssertThrowsError(try state.addTerm(yearID: yearID, title: "Spring", startDay: "2025-05-30", endDay: "2025-01-06"))

        // Delete term
        try state.deleteTerm(id: termID)
        XCTAssertTrue(state.terms.isEmpty)
        XCTAssertThrowsError(try state.deleteTerm(id: termID))

        // Deleting year cascades to its terms
        _ = try state.addTerm(yearID: yearID, title: "Semester 1", startDay: "2024-08-01", endDay: "2024-12-20")
        XCTAssertEqual(state.terms.count, 1)
        try state.deleteAcademicYear(id: yearID)
        XCTAssertTrue(state.terms.isEmpty)
    }

    func testAcademicYearQueryScoping() throws {
        var state = SchoolState()
        let year2024 = AcademicYear(
            title: "2024–2025",
            startDay: "2024-08-01",
            endDay: "2025-06-30",
            targetDays: 180,
            targetHours: 900
        )
        state.academicYears.append(year2024)

        let alice = try state.addStudent(name: "Alice", gradeLevel: "4")
        let bob = try state.addStudent(name: "Bob", gradeLevel: "2")

        // Attendance across different dates
        try state.confirmAttendance(studentID: alice, day: "2024-07-15", minutes: 60) // Before year
        try state.confirmAttendance(studentID: alice, day: "2024-09-02", minutes: 180) // In year
        try state.confirmAttendance(studentID: bob, day: "2024-09-02", minutes: 150) // In year
        try state.confirmAttendance(studentID: alice, day: "2025-07-10", minutes: 60) // After year

        // Activities
        try state.logActivity(title: "Summer Camp", studentIDs: [alice], day: "2024-07-20", minutes: 120)
        try state.logActivity(title: "Museum Tour", studentIDs: [alice, bob], day: "2024-10-15", minutes: 90)

        // Assignments
        let courseID = try state.addCourse(title: "Math", studentIDs: [alice], lessonTitles: ["Lesson 1", "Lesson 2"], startDay: nil)
        let lessonIDs = Set(state.lessons.filter { $0.courseID == courseID }.map(\.id))
        let assignments = state.assignments.filter { lessonIDs.contains($0.lessonID) }
        try state.setAssignmentStatus(id: assignments[0].id, status: .completed, completedDay: "2024-07-25") // Before year
        try state.setAssignmentStatus(id: assignments[1].id, status: .completed, completedDay: "2024-10-01") // In year

        // Query scoping for all students
        let yearAttendanceAll = state.attendance(for: nil, in: year2024)
        XCTAssertEqual(yearAttendanceAll.count, 2)

        // Query scoping for alice
        let yearAttendanceAlice = state.attendance(for: alice, in: year2024)
        XCTAssertEqual(yearAttendanceAlice.count, 1)
        XCTAssertEqual(yearAttendanceAlice.first?.day, "2024-09-02")

        // Activities scoping
        let yearActivitiesAll = state.activities(for: nil, in: year2024)
        XCTAssertEqual(yearActivitiesAll.count, 2) // alice and bob museum tour
        let yearActivitiesAlice = state.activities(for: alice, in: year2024)
        XCTAssertEqual(yearActivitiesAlice.count, 1)
        XCTAssertEqual(yearActivitiesAlice.first?.title, "Museum Tour")

        // Completed assignments scoping
        let yearAssignments = state.completedAssignments(for: alice, in: year2024)
        XCTAssertEqual(yearAssignments.count, 1)
        XCTAssertEqual(yearAssignments.first?.id, assignments[1].id)
    }

    func testBackwardCompatibleDecodingWithoutAcademicYears() throws {
        // Old schema JSON missing academicYears, terms, activeYearID
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "students": [
            { "id": "11111111-1111-1111-1111-111111111111", "name": "Alice", "gradeLevel": "4" }
          ],
          "courses": [],
          "lessons": [],
          "assignments": [],
          "attendance": [],
          "activities": []
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(SchoolState.self, from: data)

        XCTAssertEqual(decodedState.students.count, 1)
        XCTAssertEqual(decodedState.students.first?.name, "Alice")
        XCTAssertTrue(decodedState.academicYears.isEmpty)
        XCTAssertTrue(decodedState.terms.isEmpty)
        XCTAssertNil(decodedState.activeYearID)
        XCTAssertNoThrow(try decodedState.validate())

        // Default academic year resolution still works gracefully
        let resolved = decodedState.resolvedActiveAcademicYear()
        XCTAssertFalse(resolved.title.isEmpty)
        XCTAssertEqual(resolved.targetDays, 180)
    }

    func testPacedReschedulingSpreadsAcrossEligibleWeekdays() throws {
        var state = SchoolState()
        let alice = try state.addStudent(name: "Alice", gradeLevel: "5")
        let courseID = try state.addCourse(
            title: "Math",
            studentIDs: [alice],
            lessonTitles: ["L1", "L2", "L3", "L4"],
            startDay: "2026-09-14", // Mon
            weekdays: [2, 3, 4, 5, 6]
        )

        let aliceAssignments = state.assignments.filter { $0.studentID == alice }
        XCTAssertEqual(aliceAssignments.count, 4)

        // Today is Friday 2026-09-25.
        // L1 scheduled 2026-09-14 (overdue)
        // L2 scheduled 2026-09-15 (overdue)
        // L3 scheduled 2026-09-16 (overdue)
        // L4 scheduled 2026-09-17 (overdue)
        let result = try state.rescheduleOverduePaced(
            from: "2026-09-25",
            studentID: alice,
            weekdays: [2, 3, 4, 5, 6]
        )

        XCTAssertEqual(result.rescheduledCount, 4)
        XCTAssertEqual(result.affectedCoursesCount, 1)

        let updatedAssignments = state.assignments.filter { $0.studentID == alice }.sorted { a1, a2 in
            let seq1 = state.lessons.first(where: { $0.id == a1.lessonID })?.sequence ?? 0
            let seq2 = state.lessons.first(where: { $0.id == a2.lessonID })?.sequence ?? 0
            return seq1 < seq2
        }

        // L1 on Friday 2026-09-25
        XCTAssertEqual(updatedAssignments[0].scheduledDay, "2026-09-25")
        // L2 on Monday 2026-09-28
        XCTAssertEqual(updatedAssignments[1].scheduledDay, "2026-09-28")
        // L3 on Tuesday 2026-09-29
        XCTAssertEqual(updatedAssignments[2].scheduledDay, "2026-09-29")
        // L4 on Wednesday 2026-09-30
        XCTAssertEqual(updatedAssignments[3].scheduledDay, "2026-09-30")
        XCTAssertEqual(result.newCompletionDay, "2026-09-30")
        XCTAssertNoThrow(try state.validate())
    }

    func testStateCompliancePresetsCoverageAll50States() throws {
        XCTAssertGreaterThanOrEqual(StateCompliancePreset.allStates.count, 51)

        let ca = try XCTUnwrap(StateCompliancePreset.preset(for: "CA"))
        XCTAssertEqual(ca.name, "California")
        XCTAssertEqual(ca.defaultDays, 175)

        let mo = try XCTUnwrap(StateCompliancePreset.preset(for: "MO"))
        XCTAssertEqual(mo.name, "Missouri")
        XCTAssertEqual(mo.defaultHours, 1000)

        var state = SchoolState()
        try state.setSelectedStateCode("fl")
        XCTAssertEqual(state.selectedStateCode, "FL")

        try state.setSelectedStateCode(nil)
        XCTAssertNil(state.selectedStateCode)

        XCTAssertThrowsError(try state.setSelectedStateCode("ZZ_INVALID"))
    }

    func testGradeAndGPACalculationsWithHonorsWeighting() throws {
        var state = SchoolState()
        let studentID = try state.addStudent(name: "Student A", gradeLevel: "10")

        let mathID = try state.addCourse(title: "Algebra II", studentIDs: [studentID], lessonTitles: ["Quiz 1", "Quiz 2"], startDay: nil)
        try state.updateCourseCredits(id: mathID, creditHours: 1.0, weight: 4.0)

        let chemID = try state.addCourse(title: "Honors Chemistry", studentIDs: [studentID], lessonTitles: ["Lab 1", "Lab 2"], startDay: nil)
        try state.updateCourseCredits(id: chemID, creditHours: 1.0, weight: 4.5)

        // Math: Grade 95 and 95 -> Average 95.0 (A -> 4.0)
        let mathAssignments = state.assignments.filter { assignment in
            state.lessons.contains { $0.id == assignment.lessonID && $0.courseID == mathID }
        }
        try state.setAssignmentGrade(id: mathAssignments[0].id, grade: 95.0, notes: "Excellent work")
        try state.setAssignmentGrade(id: mathAssignments[1].id, grade: 95.0)

        // Chem: Grade 85 and 85 -> Average 85.0 (B -> 3.0 base, 3.5 weighted)
        let chemAssignments = state.assignments.filter { assignment in
            state.lessons.contains { $0.id == assignment.lessonID && $0.courseID == chemID }
        }
        try state.setAssignmentGrade(id: chemAssignments[0].id, grade: 85.0)
        try state.setAssignmentGrade(id: chemAssignments[1].id, grade: 85.0)

        XCTAssertEqual(state.courseGrade(for: studentID, courseID: mathID), 95.0)
        XCTAssertEqual(state.courseGrade(for: studentID, courseID: chemID), 85.0)
        XCTAssertEqual(state.courseCreditsEarned(for: studentID, courseID: mathID), 1.0)
        XCTAssertEqual(state.courseCreditsEarned(for: studentID, courseID: chemID), 1.0)

        // Unweighted GPA: (4.0 * 1.0 + 3.0 * 1.0) / 2.0 = 3.5
        let unweighted = try XCTUnwrap(state.cumulativeGPA(for: studentID, weighted: false))
        XCTAssertEqual(unweighted, 3.5, accuracy: 0.001)

        // Weighted GPA: (4.0 * 1.0 + 3.5 * 1.0) / 2.0 = 3.75
        let weighted = try XCTUnwrap(state.cumulativeGPA(for: studentID, weighted: true))
        XCTAssertEqual(weighted, 3.75, accuracy: 0.001)

        // Assignment letter grade & grade points
        let updatedMath0 = try XCTUnwrap(state.assignments.first(where: { $0.id == mathAssignments[0].id }))
        let updatedChem0 = try XCTUnwrap(state.assignments.first(where: { $0.id == chemAssignments[0].id }))
        XCTAssertEqual(updatedMath0.letterGrade, "A")
        XCTAssertEqual(updatedMath0.gradePoint, 4.0)
        XCTAssertEqual(updatedMath0.notes, "Excellent work")
        XCTAssertEqual(updatedChem0.letterGrade, "B")
        XCTAssertEqual(updatedChem0.gradePoint, 3.0)
    }

    func testParentPINVerificationAndValidation() throws {
        var state = SchoolState()
        // Default: no PIN set, verify returns true
        XCTAssertTrue(state.verifyParentPIN("1234"))

        try state.setParentPIN("9876")
        XCTAssertEqual(state.parentPIN, "9876")
        XCTAssertTrue(state.verifyParentPIN("9876"))
        XCTAssertFalse(state.verifyParentPIN("1234"))
        XCTAssertFalse(state.verifyParentPIN(""))

        // Invalid PINs
        XCTAssertThrowsError(try state.setParentPIN("123"))
        XCTAssertThrowsError(try state.setParentPIN("12345"))
        XCTAssertThrowsError(try state.setParentPIN("abcd"))

        // Clear PIN
        try state.setParentPIN(nil)
        XCTAssertNil(state.parentPIN)
        XCTAssertTrue(state.verifyParentPIN("any"))
    }

    func testBackwardCompatibilityWithAllNewFields() throws {
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "students": [
            { "id": "22222222-2222-2222-2222-222222222222", "name": "Bob", "gradeLevel": "8" }
          ],
          "courses": [
            { "id": "33333333-3333-3333-3333-333333333333", "title": "Science" }
          ],
          "lessons": [
            { "id": "44444444-4444-4444-4444-444444444444", "courseID": "33333333-3333-3333-3333-333333333333", "title": "Intro", "sequence": 1 }
          ],
          "assignments": [
            { "id": "55555555-5555-5555-5555-555555555555", "studentID": "22222222-2222-2222-2222-222222222222", "lessonID": "44444444-4444-4444-4444-444444444444", "status": "planned" }
          ],
          "attendance": [],
          "activities": []
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let state = try JSONDecoder().decode(SchoolState.self, from: data)

        XCTAssertEqual(state.students.count, 1)
        XCTAssertEqual(state.courses.count, 1)
        XCTAssertNil(state.courses[0].creditHours)
        XCTAssertNil(state.courses[0].weight)
        XCTAssertNil(state.assignments[0].grade)
        XCTAssertNil(state.assignments[0].notes)
        XCTAssertNil(state.parentPIN)
        XCTAssertNil(state.selectedStateCode)
        XCTAssertEqual(state.portfolioItems, [])
        XCTAssertNoThrow(try state.validate())
    }

    func testPortfolioItemCRUDAndValidation() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "5")
        let courseID = try state.addCourse(title: "Art", studentIDs: [aliceID], lessonTitles: ["Watercolor 101"], startDay: "2026-09-01")
        let lessonID = state.lessons.first { $0.courseID == courseID }!.id
        let assignmentID = state.assignments.first { $0.lessonID == lessonID }!.id

        // Add portfolio item
        let itemID = try state.addPortfolioItem(
            studentID: aliceID,
            title: "Watercolor Sunset",
            day: "2026-09-02",
            courseID: courseID,
            assignmentID: assignmentID,
            imageFileName: "sunset_001.jpg",
            notes: "Used wet-on-wet technique."
        )

        XCTAssertEqual(state.portfolioItems.count, 1)
        XCTAssertEqual(state.portfolioItems[0].id, itemID)
        XCTAssertEqual(state.portfolioItems[0].title, "Watercolor Sunset")
        XCTAssertEqual(state.portfolioItems[0].imageFileName, "sunset_001.jpg")

        // Validation - invalid student ID
        XCTAssertThrowsError(
            try state.addPortfolioItem(
                studentID: UUID(),
                title: "Invalid",
                day: "2026-09-02",
                imageFileName: "img.jpg"
            )
        )

        // Validation - empty title
        XCTAssertThrowsError(
            try state.addPortfolioItem(
                studentID: aliceID,
                title: "  ",
                day: "2026-09-02",
                imageFileName: "img.jpg"
            )
        )

        // Validation - invalid day
        XCTAssertThrowsError(
            try state.addPortfolioItem(
                studentID: aliceID,
                title: "Test",
                day: "2026-02-31",
                imageFileName: "img.jpg"
            )
        )

        // Update portfolio item
        try state.updatePortfolioItem(id: itemID, title: "Watercolor Sunset v2", day: "2026-09-03", notes: "Added white highlights.")
        XCTAssertEqual(state.portfolioItems[0].title, "Watercolor Sunset v2")
        XCTAssertEqual(state.portfolioItems[0].day, "2026-09-03")
        XCTAssertEqual(state.portfolioItems[0].notes, "Added white highlights.")

        // Scoped query
        let itemsForAlice = state.portfolioItems(for: aliceID, courseID: courseID)
        XCTAssertEqual(itemsForAlice.count, 1)

        let itemsForUnknownCourse = state.portfolioItems(for: aliceID, courseID: UUID())
        XCTAssertEqual(itemsForUnknownCourse.count, 0)

        // Delete portfolio item
        try state.deletePortfolioItem(id: itemID)
        XCTAssertEqual(state.portfolioItems.count, 0)
    }

    func testStudentDeletionCascadesToPortfolioItems() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "5")
        let bobID = try state.addStudent(name: "Bob", gradeLevel: "3")

        _ = try state.addPortfolioItem(studentID: aliceID, title: "Alice Artwork", day: "2026-09-05", imageFileName: "alice.jpg")
        _ = try state.addPortfolioItem(studentID: bobID, title: "Bob Essay", day: "2026-09-05", imageFileName: "bob.jpg")

        XCTAssertEqual(state.portfolioItems.count, 2)

        // Delete Alice -> Alice's portfolio items removed, Bob's remains
        try state.deleteStudent(id: aliceID)
        XCTAssertEqual(state.portfolioItems.count, 1)
        XCTAssertEqual(state.portfolioItems.first?.studentID, bobID)
    }

    func testCourseAndActivityDeletionNullifiesPortfolioItemReferences() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "5")
        let courseID = try state.addCourse(title: "Science", studentIDs: [aliceID], lessonTitles: ["Volcano Experiment"], startDay: "2026-09-01")
        let lessonID = state.lessons.first { $0.courseID == courseID }!.id
        let assignmentID = state.assignments.first { $0.lessonID == lessonID }!.id

        try state.logActivity(title: "Science Fair", studentIDs: [aliceID], day: "2026-09-10", minutes: 120)
        let activityID = state.activities.first!.id

        let itemID = try state.addPortfolioItem(
            studentID: aliceID,
            title: "Volcano Photo",
            day: "2026-09-10",
            courseID: courseID,
            assignmentID: assignmentID,
            activityID: activityID,
            imageFileName: "volcano.jpg"
        )

        // Delete course -> portfolio item retains student and activity, but courseID and assignmentID are nil
        try state.deleteCourse(id: courseID)
        let itemAfterCourseDelete = state.portfolioItems.first { $0.id == itemID }!
        XCTAssertNil(itemAfterCourseDelete.courseID)
        XCTAssertNil(itemAfterCourseDelete.assignmentID)
        XCTAssertEqual(itemAfterCourseDelete.activityID, activityID)

        // Delete activity -> activityID is nullified
        try state.deleteActivity(id: activityID)
        let itemAfterActivityDelete = state.portfolioItems.first { $0.id == itemID }!
        XCTAssertNil(itemAfterActivityDelete.activityID)
        XCTAssertNoThrow(try state.validate())
    }

    func testCalendarICSGeneration() throws {
        var state = SchoolState()
        let yearID = UUID()
        let year = AcademicYear(id: yearID, title: "2026-2027", startDay: "2026-08-01", endDay: "2027-06-30", targetDays: 180)
        state.academicYears.append(year)
        let term = AcademicTerm(academicYearID: yearID, title: "Fall Semester", startDay: "2026-08-15", endDay: "2026-12-18")
        state.terms.append(term)

        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "4")
        let courseID = try state.addCourse(title: "Math", studentIDs: [aliceID], lessonTitles: ["Addition", "Subtraction"], startDay: "2026-09-01", weekdays: [2, 3])

        let ics = HomeschoolCalendarGenerator.generateICS(state: state, studentID: aliceID, academicYear: year)

        XCTAssertTrue(ics.contains("BEGIN:VCALENDAR"))
        XCTAssertTrue(ics.contains("END:VCALENDAR"))
        XCTAssertTrue(ics.contains("SUMMARY:Fall Semester"))
        XCTAssertTrue(ics.contains("SUMMARY:Math: Addition (Alice)"))
        XCTAssertTrue(ics.contains("DTSTART;VALUE=DATE:20260901"))
        XCTAssertTrue(ics.contains("DTEND;VALUE=DATE:20260902"))
        XCTAssertTrue(ics.contains("STATUS:TENTATIVE"))
    }

    func testBookCRUDAndValidation() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "4")

        let bookID = try state.addBook(
            studentID: aliceID,
            title: "Charlotte's Web",
            author: "E.B. White",
            genre: "Classic Literature",
            format: .physical,
            status: .reading,
            totalPages: 184,
            currentPage: 25,
            rating: nil,
            notes: "Reading with dad",
            startDay: "2026-09-01"
        )

        XCTAssertEqual(state.books.count, 1)
        let book = try XCTUnwrap(state.books.first)
        XCTAssertEqual(book.title, "Charlotte's Web")
        XCTAssertEqual(book.author, "E.B. White")
        XCTAssertEqual(book.totalPages, 184)
        XCTAssertEqual(book.currentPage, 25)
        XCTAssertEqual(book.status, .reading)

        // Update book
        try state.updateBook(
            id: bookID,
            currentPage: 184,
            rating: 5,
            notes: "Finished! Beautiful ending.",
            completedDay: "2026-09-15"
        )
        let updated = try XCTUnwrap(state.books.first)
        XCTAssertEqual(updated.currentPage, 184)
        XCTAssertEqual(updated.rating, 5)
        XCTAssertEqual(updated.completedDay, "2026-09-15")

        // Validation errors
        XCTAssertThrowsError(try state.addBook(studentID: UUID(), title: "Test", author: "Author"))
        XCTAssertThrowsError(try state.addBook(studentID: aliceID, title: "", author: "Author"))
        XCTAssertThrowsError(try state.addBook(studentID: aliceID, title: "Test", author: ""))
        XCTAssertThrowsError(try state.addBook(studentID: aliceID, title: "Test", author: "Author", totalPages: -10))
        XCTAssertThrowsError(try state.addBook(studentID: aliceID, title: "Test", author: "Author", rating: 6))
        XCTAssertThrowsError(try state.addBook(studentID: aliceID, title: "Test", author: "Author", startDay: "invalid-date"))

        // Delete book
        try state.deleteBook(id: bookID)
        XCTAssertEqual(state.books.count, 0)
    }

    func testReadingLogEntryWithAutoAttendance() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "4")
        let bookID = try state.addBook(
            studentID: aliceID,
            title: "The Hobbit",
            author: "J.R.R. Tolkien",
            totalPages: 310,
            currentPage: 50,
            startDay: "2026-09-01"
        )

        // Log reading session with attendance auto-generation
        let logID = try state.addReadingLogEntry(
            bookID: bookID,
            studentID: aliceID,
            day: "2026-09-10",
            minutes: 45,
            pagesRead: 30,
            notes: "Read chapter 3",
            logToAttendance: true
        )

        XCTAssertEqual(state.readingLogs.count, 1)
        let log = try XCTUnwrap(state.readingLogs.first)
        XCTAssertEqual(log.minutes, 45)
        XCTAssertEqual(log.pagesRead, 30)
        XCTAssertNotNil(log.activityID)

        // Verifies learning activity was created
        XCTAssertEqual(state.activities.count, 1)
        let activity = try XCTUnwrap(state.activities.first)
        XCTAssertEqual(activity.id, log.activityID)
        XCTAssertEqual(activity.title, "Reading: The Hobbit")
        XCTAssertEqual(activity.minutes, 45)

        // Verifies book's currentPage updated to 50 + 30 = 80
        let book = try XCTUnwrap(state.books.first)
        XCTAssertEqual(book.currentPage, 80)
        XCTAssertEqual(book.status, .reading)

        // Log session that completes the book
        _ = try state.addReadingLogEntry(
            bookID: bookID,
            studentID: aliceID,
            day: "2026-09-15",
            minutes: 60,
            pagesRead: 230,
            logToAttendance: false
        )
        let completedBook = try XCTUnwrap(state.books.first)
        XCTAssertEqual(completedBook.currentPage, 310)
        XCTAssertEqual(completedBook.status, .completed)
        XCTAssertEqual(completedBook.completedDay, "2026-09-15")

        // Delete first reading log removes its linked activity
        try state.deleteReadingLogEntry(id: logID)
        XCTAssertEqual(state.readingLogs.count, 1)
        XCTAssertEqual(state.activities.count, 0)
    }

    func testStudentDeletionCascadesToBooksAndReadingLogs() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "4")
        let bobID = try state.addStudent(name: "Bob", gradeLevel: "2")

        let aliceBook = try state.addBook(studentID: aliceID, title: "Alice's Adventures", author: "Lewis Carroll")
        let bobBook = try state.addBook(studentID: bobID, title: "Winnie the Pooh", author: "A.A. Milne")

        _ = try state.addReadingLogEntry(bookID: aliceBook, studentID: aliceID, day: "2026-09-02", minutes: 30)
        _ = try state.addReadingLogEntry(bookID: bobBook, studentID: bobID, day: "2026-09-02", minutes: 20)

        XCTAssertEqual(state.books.count, 2)
        XCTAssertEqual(state.readingLogs.count, 2)

        // Delete Alice
        try state.deleteStudent(id: aliceID)
        XCTAssertEqual(state.books.count, 1)
        XCTAssertEqual(state.books.first?.studentID, bobID)
        XCTAssertEqual(state.readingLogs.count, 1)
        XCTAssertEqual(state.readingLogs.first?.studentID, bobID)
    }

    func testBookDeletionCascadesToReadingLogs() throws {
        var state = SchoolState()
        let aliceID = try state.addStudent(name: "Alice", gradeLevel: "4")
        let bookID = try state.addBook(studentID: aliceID, title: "Book One", author: "Author One")

        _ = try state.addReadingLogEntry(bookID: bookID, studentID: aliceID, day: "2026-09-01", minutes: 25)
        _ = try state.addReadingLogEntry(bookID: bookID, studentID: aliceID, day: "2026-09-02", minutes: 35)

        XCTAssertEqual(state.readingLogs.count, 2)

        try state.deleteBook(id: bookID)
        XCTAssertEqual(state.books.count, 0)
        XCTAssertEqual(state.readingLogs.count, 0)
    }

    func testBackwardCompatibilityWithBooksAndReadingLogs() throws {
        let jsonWithoutBooks = """
        {
            "schemaVersion": 1,
            "students": [
                {
                    "id": "11111111-1111-1111-1111-111111111111",
                    "name": "Clara",
                    "gradeLevel": "3"
                }
            ],
            "courses": [],
            "lessons": [],
            "assignments": [],
            "attendance": [],
            "activities": []
        }
        """

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SchoolState.self, from: Data(jsonWithoutBooks.utf8))
        XCTAssertEqual(decoded.students.count, 1)
        XCTAssertEqual(decoded.books.count, 0)
        XCTAssertEqual(decoded.readingLogs.count, 0)
        XCTAssertNoThrow(try decoded.validate())
    }

    func testGradeCategoryCRUDAndWeightValidation() throws {
        var state = SchoolState()
        let studentID = try state.addStudent(name: "Leo", gradeLevel: "9")
        let courseID = try state.addCourse(
            title: "Physics",
            studentIDs: [studentID],
            lessonTitles: ["L1", "L2"],
            startDay: nil,
            weekdays: []
        )

        // Add categories
        let testsID = try state.addGradeCategory(courseID: courseID, name: "Tests", weight: 0.5)
        let hwID = try state.addGradeCategory(courseID: courseID, name: "Homework", weight: 0.3)
        XCTAssertEqual(state.gradeCategories.count, 2)

        // Adding category that exceeds 100% total weight should fail
        XCTAssertThrowsError(try state.addGradeCategory(courseID: courseID, name: "Labs", weight: 0.3)) { error in
            guard case SchoolStateError.invalidValue = error else {
                return XCTFail("Expected invalidValue error but got \(error)")
            }
        }

        // Updating category
        try state.updateGradeCategory(id: hwID, name: "Daily Homework", weight: 0.4)
        let updatedHw = state.gradeCategories.first { $0.id == hwID }
        XCTAssertEqual(updatedHw?.name, "Daily Homework")
        XCTAssertEqual(updatedHw?.weight, 0.4)

        // Updating category to exceed 100% should fail
        XCTAssertThrowsError(try state.updateGradeCategory(id: hwID, weight: 0.6))

        // Deleting category
        try state.deleteGradeCategory(id: testsID)
        XCTAssertEqual(state.gradeCategories.count, 1)
        XCTAssertEqual(state.gradeCategories.first?.id, hwID)
    }

    func testWeightedCourseGradeRespectsCategoryWeights() throws {
        var state = SchoolState()
        let studentID = try state.addStudent(name: "Maya", gradeLevel: "10")
        let courseID = try state.addCourse(
            title: "Algebra II",
            studentIDs: [studentID],
            lessonTitles: ["Unit 1 Test", "Homework 1"],
            startDay: nil,
            weekdays: []
        )

        let testCatID = try state.addGradeCategory(courseID: courseID, name: "Tests", weight: 0.6)
        let hwCatID = try state.addGradeCategory(courseID: courseID, name: "Homework", weight: 0.4)

        let testLesson = state.lessons.first { $0.title == "Unit 1 Test" }!
        let hwLesson = state.lessons.first { $0.title == "Homework 1" }!

        let testAsgn = state.assignments.first { $0.lessonID == testLesson.id }!
        let hwAsgn = state.assignments.first { $0.lessonID == hwLesson.id }!

        try state.setAssignmentCategory(id: testAsgn.id, categoryID: testCatID)
        try state.setAssignmentGrade(id: testAsgn.id, grade: 100.0)

        try state.setAssignmentCategory(id: hwAsgn.id, categoryID: hwCatID)
        try state.setAssignmentGrade(id: hwAsgn.id, grade: 50.0)

        // Unweighted average would be 75.0%
        // Weighted average: (100 * 0.6 + 50 * 0.4) / (0.6 + 0.4) = (60 + 20) / 1.0 = 80.0%
        let finalGrade = state.courseGrade(for: studentID, courseID: courseID)
        XCTAssertNotNil(finalGrade)
        XCTAssertEqual(finalGrade!, 80.0, accuracy: 0.001)

        // Category averages
        let testAvg = state.categoryGrade(for: studentID, categoryID: testCatID)
        let hwAvg = state.categoryGrade(for: studentID, categoryID: hwCatID)
        XCTAssertEqual(testAvg, 100.0)
        XCTAssertEqual(hwAvg, 50.0)
    }

    func testISBNFieldOnBookEntryAndBackwardCompat() throws {
        var state = SchoolState()
        let studentID = try state.addStudent(name: "Ben", gradeLevel: "5")
        let bookID = try state.addBook(
            studentID: studentID,
            title: "The Hobbit",
            author: "J.R.R. Tolkien",
            isbn: "9780547928227"
        )

        let book = state.books.first { $0.id == bookID }
        XCTAssertEqual(book?.isbn, "9780547928227")

        try state.updateBook(id: bookID, isbn: "9780007525492")
        XCTAssertEqual(state.books.first { $0.id == bookID }?.isbn, "9780007525492")

        // Backward compatibility: JSON with no isbn and no gradeCategories decodes cleanly
        let json = """
        {
            "schemaVersion": 1,
            "students": [{"id": "\(studentID.uuidString)", "name": "Ben", "gradeLevel": "5"}],
            "courses": [],
            "lessons": [],
            "assignments": [],
            "attendance": [],
            "activities": [],
            "books": [{"id": "\(UUID().uuidString)", "studentID": "\(studentID.uuidString)", "title": "Old Book", "author": "Old Author", "format": "Physical Book", "status": "Currently Reading"}]
        }
        """
        let decoded = try JSONDecoder().decode(SchoolState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.books.count, 1)
        XCTAssertNil(decoded.books.first?.isbn)
        XCTAssertEqual(decoded.gradeCategories.count, 0)
        XCTAssertNoThrow(try decoded.validate())
    }

    func testGradeCategoryDeletionClearsAssignmentCategoryID() throws {
        var state = SchoolState()
        let studentID = try state.addStudent(name: "Sam", gradeLevel: "7")
        let courseID = try state.addCourse(
            title: "History",
            studentIDs: [studentID],
            lessonTitles: ["Chapter 1"],
            startDay: nil,
            weekdays: []
        )

        let catID = try state.addGradeCategory(courseID: courseID, name: "Quizzes", weight: 0.25)
        let asgn = state.assignments.first!
        try state.setAssignmentCategory(id: asgn.id, categoryID: catID)
        XCTAssertEqual(state.assignments.first?.categoryID, catID)

        // Deleting category should clear categoryID on assignment
        try state.deleteGradeCategory(id: catID)
        XCTAssertEqual(state.gradeCategories.count, 0)
        XCTAssertNil(state.assignments.first?.categoryID)

        // Deleting course should cascade-delete any remaining categories
        _ = try state.addGradeCategory(courseID: courseID, name: "Final", weight: 0.5)
        XCTAssertEqual(state.gradeCategories.count, 1)
        try state.deleteCourse(id: courseID)
        XCTAssertEqual(state.gradeCategories.count, 0)
    }
}

