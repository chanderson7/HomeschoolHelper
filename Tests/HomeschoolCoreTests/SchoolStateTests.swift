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
}

