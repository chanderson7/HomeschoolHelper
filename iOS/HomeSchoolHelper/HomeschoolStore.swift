import Foundation
import Combine
import HomeschoolCore

@MainActor
final class HomeschoolStore: ObservableObject {
    @Published private(set) var state = SchoolState()
    @Published private(set) var loadError: String?
    @Published var presentedError: AppMessage?
    @Published private(set) var isSaving = false
    @Published var isStudentModeActive: Bool = false
    @Published var activeStudentModeStudentID: UUID? = nil
    @Published var dailyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dailyReminderEnabled, forKey: "hsh_daily_reminder_enabled")
            syncDailyReminder()
        }
    }
    @Published var dailyReminderTime: Date {
        didSet {
            UserDefaults.standard.set(dailyReminderTime.timeIntervalSince1970, forKey: "hsh_daily_reminder_time")
            syncDailyReminder()
        }
    }

    var onSyncDailyReminder: ((Bool, Date, SchoolState) -> Void)?
    var onPortfolioItemDeleted: ((String) -> Void)?

    private let repository: any SchoolRepository

    init(repository: (any SchoolRepository)? = nil) {
        self.repository = repository ?? JSONSchoolRepository(fileURL: Self.defaultFileURL())
        self.dailyReminderEnabled = UserDefaults.standard.bool(forKey: "hsh_daily_reminder_enabled")
        let savedTime = UserDefaults.standard.double(forKey: "hsh_daily_reminder_time")
        if savedTime > 0 {
            self.dailyReminderTime = Date(timeIntervalSince1970: savedTime)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 8
            components.minute = 0
            self.dailyReminderTime = Calendar.current.date(from: components) ?? Date()
        }
        load()
        syncDailyReminder()
    }

    func syncDailyReminder() {
        onSyncDailyReminder?(dailyReminderEnabled, dailyReminderTime, state)
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
            if dailyReminderEnabled {
                syncDailyReminder()
            }
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
    func addCourse(title: String, studentIDs: [UUID], lessonTitles: [String], startDay: String?, weekdays: Set<Int>, creditHours: Double? = nil, weight: Double? = nil) -> Bool {
        update("create lesson sequence") { state in
            let courseID = try state.addCourse(
                title: title,
                studentIDs: studentIDs,
                lessonTitles: lessonTitles,
                startDay: startDay,
                weekdays: weekdays
            )
            if creditHours != nil || weight != nil {
                try state.updateCourseCredits(id: courseID, creditHours: creditHours, weight: weight)
            }
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

    @discardableResult
    func rescheduleOverduePaced(
        from startDay: String = SchoolDate.today,
        studentID: UUID? = nil,
        weekdays: Set<Int> = [2, 3, 4, 5, 6]
    ) -> PacedRescheduleResult? {
        var result: PacedRescheduleResult?
        let ok = update("smart paced reschedule") { state in
            result = try state.rescheduleOverduePaced(from: startDay, studentID: studentID, weekdays: weekdays)
        }
        return ok ? result : nil
    }

    func enterStudentMode(for studentID: UUID? = nil) {
        activeStudentModeStudentID = studentID ?? state.students.first?.id
        isStudentModeActive = true
    }

    @discardableResult
    func exitStudentMode(pin: String) -> Bool {
        guard verifyParentPIN(pin) else { return false }
        isStudentModeActive = false
        activeStudentModeStudentID = nil
        return true
    }

    @discardableResult
    func setParentPIN(_ pin: String?) -> Bool {
        update("update parent PIN") { state in
            try state.setParentPIN(pin)
        }
    }

    func verifyParentPIN(_ pin: String) -> Bool {
        state.verifyParentPIN(pin)
    }

    var hasParentPIN: Bool {
        state.parentPIN != nil
    }

    @discardableResult
    func setSelectedStateCode(_ code: String?) -> Bool {
        update("update home state compliance") { state in
            try state.setSelectedStateCode(code)
        }
    }

    var selectedStatePreset: StateCompliancePreset? {
        guard let code = state.selectedStateCode else { return nil }
        return StateCompliancePreset.preset(for: code)
    }

    @discardableResult
    func setAssignmentGrade(id: UUID, grade: Double?, notes: String? = nil) -> Bool {
        update("grade assignment") { state in
            try state.setAssignmentGrade(id: id, grade: grade, notes: notes)
        }
    }

    @discardableResult
    func updateCourseCredits(id: UUID, creditHours: Double?, weight: Double?) -> Bool {
        update("update course credits") { state in
            try state.updateCourseCredits(id: id, creditHours: creditHours, weight: weight)
        }
    }

    func courseGrade(for studentID: UUID, courseID: UUID) -> Double? {
        state.courseGrade(for: studentID, courseID: courseID)
    }

    func courseCreditsEarned(for studentID: UUID, courseID: UUID) -> Double {
        state.courseCreditsEarned(for: studentID, courseID: courseID)
    }

    func cumulativeGPA(for studentID: UUID, weighted: Bool) -> Double? {
        state.cumulativeGPA(for: studentID, weighted: weighted)
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

    @discardableResult
    func updateStudent(id: UUID, name: String, gradeLevel: String) -> Bool {
        update("update student") { state in
            try state.updateStudent(id: id, name: name, gradeLevel: gradeLevel)
        }
    }

    @discardableResult
    func deleteStudent(id: UUID) -> Bool {
        update("delete student") { state in
            try state.deleteStudent(id: id)
        }
    }

    @discardableResult
    func updateCourse(id: UUID, title: String) -> Bool {
        update("update course") { state in
            try state.updateCourse(id: id, title: title)
        }
    }

    @discardableResult
    func deleteCourse(id: UUID) -> Bool {
        update("delete course") { state in
            try state.deleteCourse(id: id)
        }
    }

    @discardableResult
    func updateLesson(id: UUID, title: String) -> Bool {
        update("update lesson") { state in
            try state.updateLesson(id: id, title: title)
        }
    }

    @discardableResult
    func deleteLesson(id: UUID) -> Bool {
        update("delete lesson") { state in
            try state.deleteLesson(id: id)
        }
    }

    @discardableResult
    func addLesson(to courseID: UUID, title: String) -> Bool {
        update("add lesson") { state in
            _ = try state.addLesson(courseID: courseID, title: title)
        }
    }

    @discardableResult
    func reorderLessons(courseID: UUID, lessonIDsInOrder: [UUID]) -> Bool {
        update("reorder lessons") { state in
            try state.reorderLessons(courseID: courseID, lessonIDsInOrder: lessonIDsInOrder)
        }
    }

    @discardableResult
    func updateAttendance(id: UUID, day: String? = nil, minutes: Int) -> Bool {
        update("update attendance") { state in
            try state.updateAttendance(id: id, day: day, minutes: minutes)
        }
    }

    @discardableResult
    func deleteAttendance(id: UUID) -> Bool {
        update("delete attendance") { state in
            try state.deleteAttendance(id: id)
        }
    }

    @discardableResult
    func updateActivity(id: UUID, title: String, day: String, minutes: Int) -> Bool {
        update("update activity") { state in
            try state.updateActivity(id: id, title: title, day: day, minutes: minutes)
        }
    }

    @discardableResult
    func deleteActivity(id: UUID) -> Bool {
        update("delete activity") { state in
            try state.deleteActivity(id: id)
        }
    }

    @discardableResult
    func addAcademicYear(
        title: String,
        startDay: String,
        endDay: String,
        targetDays: Int = 180,
        targetHours: Int? = nil,
        makeActive: Bool = false
    ) -> Bool {
        update("add academic year") { state in
            _ = try state.addAcademicYear(
                title: title,
                startDay: startDay,
                endDay: endDay,
                targetDays: targetDays,
                targetHours: targetHours,
                makeActive: makeActive
            )
        }
    }

    @discardableResult
    func updateAcademicYear(
        id: UUID,
        title: String,
        startDay: String,
        endDay: String,
        targetDays: Int,
        targetHours: Int?
    ) -> Bool {
        update("update academic year") { state in
            try state.updateAcademicYear(
                id: id,
                title: title,
                startDay: startDay,
                endDay: endDay,
                targetDays: targetDays,
                targetHours: targetHours
            )
        }
    }

    @discardableResult
    func deleteAcademicYear(id: UUID) -> Bool {
        update("delete academic year") { state in
            try state.deleteAcademicYear(id: id)
        }
    }

    @discardableResult
    func setActiveAcademicYear(id: UUID?) -> Bool {
        update("set active academic year") { state in
            try state.setActiveAcademicYear(id: id)
        }
    }

    @discardableResult
    func addTerm(
        yearID: UUID,
        title: String,
        startDay: String,
        endDay: String
    ) -> Bool {
        update("add term") { state in
            _ = try state.addTerm(yearID: yearID, title: title, startDay: startDay, endDay: endDay)
        }
    }

    @discardableResult
    func deleteTerm(id: UUID) -> Bool {
        update("delete term") { state in
            try state.deleteTerm(id: id)
        }
    }

    @discardableResult
    func addPortfolioItem(
        studentID: UUID,
        title: String,
        day: String,
        courseID: UUID? = nil,
        assignmentID: UUID? = nil,
        activityID: UUID? = nil,
        imageFileName: String,
        notes: String? = nil
    ) -> Bool {
        update("add work sample") { state in
            _ = try state.addPortfolioItem(
                studentID: studentID,
                title: title,
                day: day,
                courseID: courseID,
                assignmentID: assignmentID,
                activityID: activityID,
                imageFileName: imageFileName,
                notes: notes
            )
        }
    }

    @discardableResult
    func updatePortfolioItem(
        id: UUID,
        title: String,
        day: String? = nil,
        notes: String? = nil
    ) -> Bool {
        update("update work sample") { state in
            try state.updatePortfolioItem(id: id, title: title, day: day, notes: notes)
        }
    }

    @discardableResult
    func deletePortfolioItem(id: UUID, imageFileName: String? = nil) -> Bool {
        let success = update("delete work sample") { state in
            try state.deletePortfolioItem(id: id)
        }
        if success, let imageFileName {
            onPortfolioItemDeleted?(imageFileName)
        }
        return success
    }

    func portfolioItems(
        for studentID: UUID? = nil,
        courseID: UUID? = nil,
        in year: AcademicYear? = nil
    ) -> [PortfolioItem] {
        let targetYear = year ?? activeAcademicYear
        return state.portfolioItems(for: studentID, courseID: courseID, in: targetYear)
    }

    // MARK: - Book & Reading Log Operations

    @discardableResult
    func addBook(
        studentID: UUID,
        title: String,
        author: String,
        genre: String? = nil,
        format: BookFormat = .physical,
        status: BookStatus = .reading,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        startDay: String? = nil,
        completedDay: String? = nil,
        academicYearID: UUID? = nil
    ) -> Bool {
        update("add book") { state in
            _ = try state.addBook(
                studentID: studentID,
                title: title,
                author: author,
                genre: genre,
                format: format,
                status: status,
                totalPages: totalPages,
                currentPage: currentPage,
                rating: rating,
                notes: notes,
                startDay: startDay,
                completedDay: completedDay,
                academicYearID: academicYearID
            )
        }
    }

    @discardableResult
    func updateBook(
        id: UUID,
        title: String? = nil,
        author: String? = nil,
        genre: String? = nil,
        format: BookFormat? = nil,
        status: BookStatus? = nil,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        startDay: String? = nil,
        completedDay: String? = nil,
        academicYearID: UUID? = nil
    ) -> Bool {
        update("update book") { state in
            try state.updateBook(
                id: id,
                title: title,
                author: author,
                genre: genre,
                format: format,
                status: status,
                totalPages: totalPages,
                currentPage: currentPage,
                rating: rating,
                notes: notes,
                startDay: startDay,
                completedDay: completedDay,
                academicYearID: academicYearID
            )
        }
    }

    @discardableResult
    func deleteBook(id: UUID) -> Bool {
        update("delete book") { state in
            try state.deleteBook(id: id)
        }
    }

    @discardableResult
    func addReadingLogEntry(
        bookID: UUID,
        studentID: UUID,
        day: String,
        minutes: Int,
        pagesRead: Int? = nil,
        notes: String? = nil,
        logToAttendance: Bool = false
    ) -> Bool {
        update("log reading session") { state in
            _ = try state.addReadingLogEntry(
                bookID: bookID,
                studentID: studentID,
                day: day,
                minutes: minutes,
                pagesRead: pagesRead,
                notes: notes,
                logToAttendance: logToAttendance
            )
        }
    }

    @discardableResult
    func deleteReadingLogEntry(id: UUID) -> Bool {
        update("delete reading session") { state in
            try state.deleteReadingLogEntry(id: id)
        }
    }

    func books(
        for studentID: UUID? = nil,
        status: BookStatus? = nil,
        in year: AcademicYear? = nil
    ) -> [BookEntry] {
        state.books(for: studentID, status: status, in: year)
    }

    func readingLogs(
        for studentID: UUID? = nil,
        bookID: UUID? = nil,
        in year: AcademicYear? = nil
    ) -> [ReadingLogEntry] {
        state.readingLogs(for: studentID, bookID: bookID, in: year)
    }

    func totalReadingMinutes(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> Int {
        readingLogs(for: studentID, in: year).reduce(0) { $0 + $1.minutes }
    }

    func totalBooksCompleted(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> Int {
        books(for: studentID, status: .completed, in: year).count
    }

    var activeAcademicYear: AcademicYear {
        state.resolvedActiveAcademicYear()
    }

    func academicYear(for id: UUID) -> AcademicYear? {
        state.academicYears.first { $0.id == id }
    }

    func terms(for yearID: UUID) -> [AcademicTerm] {
        state.terms.filter { $0.academicYearID == yearID }.sorted { $0.startDay < $1.startDay }
    }

    func attendance(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> [AttendanceEntry] {
        let targetYear = year ?? activeAcademicYear
        return state.attendance(for: studentID, in: targetYear)
    }

    func attendanceDaysCount(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> Int {
        Set(attendance(for: studentID, in: year).map(\.day)).count
    }

    func instructionalMinutes(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> Int {
        attendance(for: studentID, in: year).reduce(0) { $0 + $1.minutes }
    }

    func completedAssignments(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> [Assignment] {
        let targetYear = year ?? activeAcademicYear
        return state.completedAssignments(for: studentID, in: targetYear)
    }

    func activities(for studentID: UUID? = nil, in year: AcademicYear? = nil) -> [LearningActivity] {
        let targetYear = year ?? activeAcademicYear
        return state.activities(for: studentID, in: targetYear)
    }

    func student(for id: UUID) -> Student? { state.students.first { $0.id == id } }
    func course(for id: UUID) -> Course? { state.courses.first { $0.id == id } }
    func lesson(for id: UUID) -> Lesson? { state.lessons.first { $0.id == id } }
    func course(for lesson: Lesson) -> Course? { state.courses.first { $0.id == lesson.courseID } }
    func activity(for id: UUID) -> LearningActivity? { state.activities.first { $0.id == id } }
    func attendance(for id: UUID) -> AttendanceEntry? { state.attendance.first { $0.id == id } }
    func portfolioItem(for id: UUID) -> PortfolioItem? { state.portfolioItems.first { $0.id == id } }

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

    static func accountFileURL(userID: UUID) -> URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("HomeSchoolHelper/accounts", isDirectory: true)
            .appendingPathComponent(userID.uuidString, isDirectory: true)
            .appendingPathComponent("school-state.json")
    }

    /// Replacing records is only invoked after an explicit user confirmation.
    @discardableResult
    func restore(_ snapshot: SchoolState) -> Bool {
        update("restore records") { copy in
            try snapshot.validate()
            copy = snapshot
        }
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
