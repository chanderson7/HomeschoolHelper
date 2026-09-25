import XCTest
@testable import HomeschoolCore
@testable import HomeschoolPresentation

final class HomeschoolStoreTests: XCTestCase {
    func testAccountPathsAreDistinctFromEachOtherAndLegacyRecords() async {
        await MainActor.run {
            let first = HomeschoolStore.accountFileURL(userID: UUID())
            let second = HomeschoolStore.accountFileURL(userID: UUID())
            XCTAssertNotEqual(first, second)
            XCTAssertNotEqual(first, HomeschoolStore.defaultFileURL())
            XCTAssertTrue(first.path.contains("HomeSchoolHelper/accounts/"))
        }
    }

    func testInvalidRestorePreservesOriginalRecords() async {
        let original = SchoolState(students: [Student(name: "Ada", gradeLevel: "4")])
        let repository = InMemorySchoolRepository(state: original)
        await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            var invalid = SchoolState()
            invalid.students = [Student(name: "", gradeLevel: "4")]
            XCTAssertFalse(store.restore(invalid))
            XCTAssertEqual(store.state, original)
            XCTAssertTrue(repository.savedStates.isEmpty)
        }
    }

    func testFreshLoadPublishesRepositoryState() async {
        let student = Student(name: "Ada", gradeLevel: "4")
        let repository = InMemorySchoolRepository(state: SchoolState(students: [student]))

        let result = await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            return (store.state, store.loadError)
        }

        XCTAssertEqual(result.0, SchoolState(students: [student]))
        XCTAssertNil(result.1)
        XCTAssertEqual(repository.loadCallCount, 1)
    }

    func testFailedSaveKeepsStateUnchangedAndShowsError() async {
        let original = SchoolState(students: [Student(name: "Ada", gradeLevel: "4")])
        let repository = InMemorySchoolRepository(state: original)
        repository.saveFailure = FakeRepositoryError.saveFailed

        let result = await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            let before = store.state
            let didUpdate = store.update("add student") { state in
                _ = try state.addStudent(name: "Grace", gradeLevel: "5")
            }
            return (
                didUpdate,
                store.state,
                before,
                store.presentedError?.title,
                store.presentedError?.message,
                store.isSaving
            )
        }

        XCTAssertFalse(result.0)
        XCTAssertEqual(result.1, result.2)
        XCTAssertEqual(result.1, original)
        XCTAssertEqual(result.3, "Couldn’t add student")
        XCTAssertEqual(result.4, FakeRepositoryError.saveFailed.localizedDescription)
        XCTAssertFalse(result.5)
        XCTAssertTrue(repository.savedStates.isEmpty)
    }

    func testLoadFailureBlocksEdits() async {
        let repository = InMemorySchoolRepository(state: SchoolState())
        repository.loadFailure = FakeRepositoryError.loadFailed

        let result = await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            let before = store.state
            var mutationRan = false
            let didUpdate = store.update("add student") { state in
                mutationRan = true
                _ = try state.addStudent(name: "Ada", gradeLevel: "4")
            }
            return (store.state, before, store.loadError, didUpdate, mutationRan)
        }

        XCTAssertEqual(result.0, result.1)
        XCTAssertEqual(result.0, SchoolState())
        XCTAssertEqual(result.2, FakeRepositoryError.loadFailed.localizedDescription)
        XCTAssertFalse(result.3)
        XCTAssertFalse(result.4)
        XCTAssertTrue(repository.savedStates.isEmpty)
    }

    func testRetryingLoadAfterFailureRecovers() async {
        let repository = InMemorySchoolRepository(state: SchoolState())
        repository.loadFailure = FakeRepositoryError.loadFailed
        let recovered = SchoolState(students: [Student(name: "Grace", gradeLevel: "5")])

        let result = await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            repository.loadFailure = nil
            repository.state = recovered
            store.load()
            return (store.state, store.loadError)
        }

        XCTAssertEqual(result.0, recovered)
        XCTAssertNil(result.1)
        XCTAssertEqual(repository.loadCallCount, 2)
    }

    func testSuccessfulMutationPublishesAndSavesNewState() async {
        let repository = InMemorySchoolRepository(state: SchoolState())

        let result = await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            let didUpdate = store.addStudent(name: "Ada", gradeLevel: "4")
            return (didUpdate, store.state, store.presentedError == nil, store.isSaving)
        }

        XCTAssertTrue(result.0)
        XCTAssertEqual(result.1.students.count, 1)
        XCTAssertEqual(result.1.students.first?.name, "Ada")
        XCTAssertEqual(result.1.students.first?.gradeLevel, "4")
        XCTAssertEqual(repository.savedStates, [result.1])
        XCTAssertTrue(result.2)
        XCTAssertFalse(result.3)
    }

    func testToggleAssignmentStatusAndRescheduleOverdue() async {
        let repository = InMemorySchoolRepository(state: SchoolState())

        let result = await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            _ = store.addStudent(name: "Ada", gradeLevel: "4")
            let student = store.state.students[0]
            _ = store.addCourse(
                title: "Math",
                studentIDs: [student.id],
                lessonTitles: ["L1", "L2"],
                startDay: "2024-01-01",
                weekdays: [2, 3, 4, 5, 6]
            )
            let assignment1 = store.state.assignments[0]
            XCTAssertEqual(assignment1.status, .planned)

            _ = store.toggleAssignmentStatus(assignment1)
            let updated1 = store.state.assignments.first { $0.id == assignment1.id }!
            XCTAssertEqual(updated1.status, .completed)
            XCTAssertEqual(updated1.completedDay, SchoolDate.today)

            _ = store.toggleAssignmentStatus(updated1)
            let toggledBack = store.state.assignments.first { $0.id == assignment1.id }!
            XCTAssertEqual(toggledBack.status, .planned)
            XCTAssertNil(toggledBack.completedDay)

            let overdue = store.overdueAssignments(asOf: "2024-01-10")
            XCTAssertEqual(overdue.count, 2)

            _ = store.rescheduleOverdue(to: "2024-01-10", studentID: student.id)
            let overdueAfter = store.overdueAssignments(asOf: "2024-01-10")
            XCTAssertEqual(overdueAfter.count, 0)

            return store.state.assignments.map(\.scheduledDay)
        }

        XCTAssertEqual(result, ["2024-01-10", "2024-01-10"])
    }

    func testStudentAndCourseCRUDInStore() async {
        let repository = InMemorySchoolRepository(state: SchoolState())

        await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            _ = store.addStudent(name: "Ada", gradeLevel: "4")
            let student = store.state.students[0]

            // Update student
            let updated = store.updateStudent(id: student.id, name: "Ada Lovelace", gradeLevel: "5")
            XCTAssertTrue(updated)
            XCTAssertEqual(store.student(for: student.id)?.name, "Ada Lovelace")
            XCTAssertEqual(store.student(for: student.id)?.gradeLevel, "5")

            // Add and Update course
            _ = store.addCourse(title: "CS", studentIDs: [student.id], lessonTitles: ["Intro"], startDay: nil, weekdays: [2])
            let course = store.state.courses[0]
            let courseUpdated = store.updateCourse(id: course.id, title: "Computer Science")
            XCTAssertTrue(courseUpdated)
            XCTAssertEqual(store.course(for: course.id)?.title, "Computer Science")

            // Delete course
            let courseDeleted = store.deleteCourse(id: course.id)
            XCTAssertTrue(courseDeleted)
            XCTAssertTrue(store.state.courses.isEmpty)
            XCTAssertTrue(store.state.lessons.isEmpty)
            XCTAssertTrue(store.state.assignments.isEmpty)

            // Delete student
            let studentDeleted = store.deleteStudent(id: student.id)
            XCTAssertTrue(studentDeleted)
            XCTAssertTrue(store.state.students.isEmpty)
        }
    }

    func testLessonAttendanceAndActivityCRUDInStore() async {
        let repository = InMemorySchoolRepository(state: SchoolState())

        await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            _ = store.addStudent(name: "Ben", gradeLevel: "2")
            let student = store.state.students[0]
            _ = store.addCourse(title: "Art", studentIDs: [student.id], lessonTitles: ["Sketching"], startDay: nil, weekdays: [2])
            let course = store.state.courses[0]
            let lesson1 = store.state.lessons[0]

            // Add lesson
            let addedLesson = store.addLesson(to: course.id, title: "Painting")
            XCTAssertTrue(addedLesson)
            XCTAssertEqual(store.state.lessons.count, 2)
            let lesson2 = store.state.lessons.first { $0.title == "Painting" }!

            // Update lesson
            let updatedLesson = store.updateLesson(id: lesson2.id, title: "Watercolors")
            XCTAssertTrue(updatedLesson)
            XCTAssertEqual(store.lesson(for: lesson2.id)?.title, "Watercolors")

            // Reorder lessons
            let reordered = store.reorderLessons(courseID: course.id, lessonIDsInOrder: [lesson2.id, lesson1.id])
            XCTAssertTrue(reordered)
            XCTAssertEqual(store.lesson(for: lesson2.id)?.sequence, 1)
            XCTAssertEqual(store.lesson(for: lesson1.id)?.sequence, 2)

            // Delete lesson
            let deletedLesson = store.deleteLesson(id: lesson1.id)
            XCTAssertTrue(deletedLesson)
            XCTAssertEqual(store.state.lessons.count, 1)
            XCTAssertEqual(store.lesson(for: lesson2.id)?.sequence, 1)

            // Attendance CRUD
            _ = store.confirmAttendance(studentID: student.id, day: "2024-05-15", minutes: 60)
            let attendance = store.attendanceEntry(for: student.id, day: "2024-05-15")!
            let updatedAtt = store.updateAttendance(id: attendance.id, day: "2024-05-16", minutes: 90)
            XCTAssertTrue(updatedAtt)
            XCTAssertEqual(store.attendance(for: attendance.id)?.day, "2024-05-16")
            XCTAssertEqual(store.attendance(for: attendance.id)?.minutes, 90)

            let deletedAtt = store.deleteAttendance(id: attendance.id)
            XCTAssertTrue(deletedAtt)
            XCTAssertNil(store.attendance(for: attendance.id))

            // Activity CRUD
            _ = store.logActivity(title: "Drawing", studentIDs: [student.id], day: "2024-05-16", minutes: 30)
            let activity = store.state.activities[0]
            let updatedAct = store.updateActivity(id: activity.id, title: "Outdoor Sketching", day: "2024-05-17", minutes: 45)
            XCTAssertTrue(updatedAct)
            XCTAssertEqual(store.activity(for: activity.id)?.title, "Outdoor Sketching")
            XCTAssertEqual(store.activity(for: activity.id)?.minutes, 45)

            let deletedAct = store.deleteActivity(id: activity.id)
            XCTAssertTrue(deletedAct)
            XCTAssertNil(store.activity(for: activity.id))
        }
    }

    func testAcademicYearAndTermCRUDInStore() async {
        let repository = InMemorySchoolRepository(state: SchoolState())
        await MainActor.run {
            let store = HomeschoolStore(repository: repository)
            _ = store.addStudent(name: "Charlie", gradeLevel: "3")
            let student = store.state.students[0]

            // Add academic year
            let addedYear = store.addAcademicYear(
                title: "2024–2025",
                startDay: "2024-08-01",
                endDay: "2025-06-30",
                targetDays: 180,
                targetHours: 900,
                makeActive: true
            )
            XCTAssertTrue(addedYear)
            XCTAssertEqual(store.state.academicYears.count, 1)
            let year = store.state.academicYears[0]
            XCTAssertEqual(store.activeAcademicYear.id, year.id)
            XCTAssertEqual(store.academicYear(for: year.id)?.title, "2024–2025")

            // Update academic year
            let updatedYear = store.updateAcademicYear(
                id: year.id,
                title: "2024–2025 Year",
                startDay: "2024-08-15",
                endDay: "2025-06-15",
                targetDays: 175,
                targetHours: 875
            )
            XCTAssertTrue(updatedYear)
            XCTAssertEqual(store.academicYear(for: year.id)?.title, "2024–2025 Year")
            XCTAssertEqual(store.academicYear(for: year.id)?.targetDays, 175)

            // Add term
            let addedTerm = store.addTerm(
                yearID: year.id,
                title: "Fall Semester",
                startDay: "2024-08-15",
                endDay: "2024-12-20"
            )
            XCTAssertTrue(addedTerm)
            XCTAssertEqual(store.terms(for: year.id).count, 1)
            let term = store.terms(for: year.id)[0]
            XCTAssertEqual(term.title, "Fall Semester")

            // Attendance and scoping
            _ = store.confirmAttendance(studentID: student.id, day: "2024-09-10", minutes: 120)
            _ = store.confirmAttendance(studentID: student.id, day: "2024-09-11", minutes: 180)
            _ = store.confirmAttendance(studentID: student.id, day: "2024-07-01", minutes: 60) // Out of year

            let currentYear = store.academicYear(for: year.id)!
            XCTAssertEqual(store.attendance(for: student.id, in: currentYear).count, 2)
            XCTAssertEqual(store.attendanceDaysCount(for: student.id, in: currentYear), 2)
            XCTAssertEqual(store.instructionalMinutes(for: student.id, in: currentYear), 300)

            // Delete term
            let deletedTerm = store.deleteTerm(id: term.id)
            XCTAssertTrue(deletedTerm)
            XCTAssertTrue(store.terms(for: year.id).isEmpty)

            // Delete year
            let deletedYear = store.deleteAcademicYear(id: year.id)
            XCTAssertTrue(deletedYear)
            XCTAssertTrue(store.state.academicYears.isEmpty)
        }
    }

    func testPacedRescheduleStudentModeAndGradingInStore() async {
        await MainActor.run {
            let repository = InMemorySchoolRepository(state: SchoolState())
            let store = HomeschoolStore(repository: repository)

            // Setup student and course
            _ = store.addStudent(name: "Charlie", gradeLevel: "9")
            let student = store.state.students[0]
            _ = store.addCourse(
                title: "Literature",
                studentIDs: [student.id],
                lessonTitles: ["Ch 1", "Ch 2", "Ch 3"],
                startDay: "2026-09-01",
                weekdays: [2, 3, 4, 5, 6]
            )
            let course = store.state.courses[0]

            // Paced Reschedule
            let result = store.rescheduleOverduePaced(from: "2026-09-25", studentID: student.id)
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.rescheduledCount, 3)

            // PIN & Student Mode
            XCTAssertFalse(store.hasParentPIN)
            XCTAssertTrue(store.setParentPIN("4321"))
            XCTAssertTrue(store.hasParentPIN)
            XCTAssertTrue(store.verifyParentPIN("4321"))
            XCTAssertFalse(store.verifyParentPIN("0000"))

            store.enterStudentMode(for: student.id)
            XCTAssertTrue(store.isStudentModeActive)
            XCTAssertEqual(store.activeStudentModeStudentID, student.id)

            // Exit with wrong PIN fails
            XCTAssertFalse(store.exitStudentMode(pin: "9999"))
            XCTAssertTrue(store.isStudentModeActive)

            // Exit with correct PIN succeeds
            XCTAssertTrue(store.exitStudentMode(pin: "4321"))
            XCTAssertFalse(store.isStudentModeActive)

            // State Compliance
            XCTAssertTrue(store.setSelectedStateCode("CA"))
            XCTAssertEqual(store.selectedStatePreset?.code, "CA")
            XCTAssertEqual(store.selectedStatePreset?.defaultDays, 175)

            // Grading and GPA
            XCTAssertTrue(store.updateCourseCredits(id: course.id, creditHours: 1.0, weight: 4.0))
            let assignmentID = store.state.assignments[0].id
            XCTAssertTrue(store.setAssignmentGrade(id: assignmentID, grade: 92.0, notes: "Good analysis"))
            XCTAssertEqual(store.courseGrade(for: student.id, courseID: course.id), 92.0)
            XCTAssertEqual(store.courseCreditsEarned(for: student.id, courseID: course.id), 1.0)
            XCTAssertEqual(store.cumulativeGPA(for: student.id, weighted: false), 3.7)
        }
    }

    func testPortfolioManagementInStore() async {
        let student = Student(name: "Leo", gradeLevel: "6")
        let repository = InMemorySchoolRepository(state: SchoolState(students: [student]))
        await MainActor.run {
            let store = HomeschoolStore(repository: repository)

            var deletedImageFile: String?
            store.onPortfolioItemDeleted = { file in
                deletedImageFile = file
            }

            // Add portfolio item
            XCTAssertTrue(store.addPortfolioItem(
                studentID: student.id,
                title: "Robotics Blueprint",
                day: "2026-09-12",
                imageFileName: "blueprint.jpg",
                notes: "Initial prototype sketch"
            ))
            XCTAssertEqual(store.state.portfolioItems.count, 1)
            let item = store.state.portfolioItems[0]
            XCTAssertEqual(item.title, "Robotics Blueprint")
            XCTAssertEqual(store.portfolioItem(for: item.id)?.title, "Robotics Blueprint")
            XCTAssertEqual(store.portfolioItems(for: student.id).count, 1)

            // Update portfolio item
            XCTAssertTrue(store.updatePortfolioItem(id: item.id, title: "Robotics Blueprint v2", notes: "Added gear ratio math"))
            XCTAssertEqual(store.portfolioItem(for: item.id)?.title, "Robotics Blueprint v2")

            // Delete portfolio item with image cleanup callback
            XCTAssertTrue(store.deletePortfolioItem(id: item.id, imageFileName: item.imageFileName))
            XCTAssertEqual(store.state.portfolioItems.count, 0)
            XCTAssertEqual(deletedImageFile, "blueprint.jpg")
        }
    }

    func testDailyReminderSettingsInStore() async {
        let repository = InMemorySchoolRepository(state: SchoolState())
        await MainActor.run {
            let store = HomeschoolStore(repository: repository)

            var syncCalled = false
            store.onSyncDailyReminder = { enabled, time, state in
                syncCalled = true
            }

            store.dailyReminderEnabled = true
            XCTAssertTrue(store.dailyReminderEnabled)
            XCTAssertTrue(syncCalled)
        }
    }

    func testStoreBookAndReadingLogMutations() async {
        let student = Student(name: "Ada", gradeLevel: "4")
        let repository = InMemorySchoolRepository(state: SchoolState(students: [student]))
        await MainActor.run {
            let store = HomeschoolStore(repository: repository)

            // Add book
            XCTAssertTrue(store.addBook(
                studentID: student.id,
                title: "Little House in the Big Woods",
                author: "Laura Ingalls Wilder",
                genre: "Historical Fiction",
                totalPages: 238,
                currentPage: 10
            ))
            XCTAssertEqual(store.state.books.count, 1)
            let book = store.state.books[0]
            XCTAssertEqual(book.title, "Little House in the Big Woods")
            XCTAssertEqual(store.books(for: student.id).count, 1)

            // Update book
            XCTAssertTrue(store.updateBook(id: book.id, currentPage: 50, rating: 4))
            XCTAssertEqual(store.books(for: student.id).first?.currentPage, 50)
            XCTAssertEqual(store.books(for: student.id).first?.rating, 4)

            // Log reading session
            XCTAssertTrue(store.addReadingLogEntry(
                bookID: book.id,
                studentID: student.id,
                day: "2026-09-18",
                minutes: 30,
                pagesRead: 20,
                logToAttendance: true
            ))
            XCTAssertEqual(store.state.readingLogs.count, 1)
            XCTAssertEqual(store.readingLogs(for: student.id).count, 1)
            XCTAssertEqual(store.totalReadingMinutes(for: student.id), 30)
            XCTAssertEqual(store.books(for: student.id).first?.currentPage, 70)

            // Delete reading log
            let log = store.state.readingLogs[0]
            XCTAssertTrue(store.deleteReadingLogEntry(id: log.id))
            XCTAssertEqual(store.state.readingLogs.count, 0)
            XCTAssertEqual(store.totalReadingMinutes(for: student.id), 0)

            // Delete book
            XCTAssertTrue(store.deleteBook(id: book.id))
            XCTAssertEqual(store.state.books.count, 0)
        }
    }
}

private enum FakeRepositoryError: LocalizedError, Sendable {
    case loadFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "The in-memory load failed."
        case .saveFailed:
            return "The in-memory save failed."
        }
    }
}

private final class InMemorySchoolRepository: SchoolRepository, @unchecked Sendable {
    var state: SchoolState
    var loadFailure: Error?
    var saveFailure: Error?
    private(set) var loadCallCount = 0
    private(set) var savedStates: [SchoolState] = []

    init(state: SchoolState) {
        self.state = state
    }

    func load() throws -> SchoolState {
        loadCallCount += 1
        if let loadFailure {
            throw loadFailure
        }
        return state
    }

    func save(_ state: SchoolState) throws {
        if let saveFailure {
            throw saveFailure
        }
        self.state = state
        savedStates.append(state)
    }
}
