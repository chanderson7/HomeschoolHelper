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
