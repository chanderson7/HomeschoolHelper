import XCTest
@testable import HomeschoolCore
@testable import HomeschoolPresentation

final class HomeschoolStoreTests: XCTestCase {
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
