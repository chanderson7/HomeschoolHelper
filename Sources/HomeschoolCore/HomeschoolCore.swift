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
    public var creditHours: Double?
    public var weight: Double?

    public init(
        id: UUID = UUID(),
        title: String,
        creditHours: Double? = nil,
        weight: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.creditHours = creditHours
        self.weight = weight
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, creditHours, weight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        creditHours = try container.decodeIfPresent(Double.self, forKey: .creditHours)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
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
    public var grade: Double?
    public var notes: String?
    public var categoryID: UUID?

    public init(
        id: UUID = UUID(),
        studentID: UUID,
        lessonID: UUID,
        scheduledDay: String? = nil,
        status: AssignmentStatus = .planned,
        completedDay: String? = nil,
        grade: Double? = nil,
        notes: String? = nil,
        categoryID: UUID? = nil
    ) {
        self.id = id
        self.studentID = studentID
        self.lessonID = lessonID
        self.scheduledDay = scheduledDay
        self.status = status
        self.completedDay = completedDay
        self.grade = grade
        self.notes = notes
        self.categoryID = categoryID
    }

    public var letterGrade: String? {
        guard let grade else { return nil }
        switch grade {
        case 97...: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 65..<70: return "D"
        default: return "F"
        }
    }

    public var gradePoint: Double? {
        guard let grade else { return nil }
        switch grade {
        case 93...: return 4.0
        case 90..<93: return 3.7
        case 87..<90: return 3.3
        case 83..<87: return 3.0
        case 80..<83: return 2.7
        case 77..<80: return 2.3
        case 73..<77: return 2.0
        case 70..<73: return 1.7
        case 65..<70: return 1.0
        default: return 0.0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, studentID, lessonID, scheduledDay, status, completedDay, grade, notes, categoryID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        studentID = try container.decode(UUID.self, forKey: .studentID)
        lessonID = try container.decode(UUID.self, forKey: .lessonID)
        scheduledDay = try container.decodeIfPresent(String.self, forKey: .scheduledDay)
        status = try container.decode(AssignmentStatus.self, forKey: .status)
        completedDay = try container.decodeIfPresent(String.self, forKey: .completedDay)
        grade = try container.decodeIfPresent(Double.self, forKey: .grade)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
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

public struct AcademicYear: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var startDay: String
    public var endDay: String
    public var targetDays: Int
    public var targetHours: Int?

    public init(
        id: UUID = UUID(),
        title: String,
        startDay: String,
        endDay: String,
        targetDays: Int = 180,
        targetHours: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.startDay = startDay
        self.endDay = endDay
        self.targetDays = targetDays
        self.targetHours = targetHours
    }

    public func contains(day: String) -> Bool {
        day >= startDay && day <= endDay
    }
}

public struct AcademicTerm: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var academicYearID: UUID
    public var title: String
    public var startDay: String
    public var endDay: String

    public init(
        id: UUID = UUID(),
        academicYearID: UUID,
        title: String,
        startDay: String,
        endDay: String
    ) {
        self.id = id
        self.academicYearID = academicYearID
        self.title = title
        self.startDay = startDay
        self.endDay = endDay
    }

    public func contains(day: String) -> Bool {
        day >= startDay && day <= endDay
    }
}

public struct PortfolioItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var studentID: UUID
    public var title: String
    public var day: String
    public var courseID: UUID?
    public var assignmentID: UUID?
    public var activityID: UUID?
    public var imageFileName: String
    public var notes: String?

    public init(
        id: UUID = UUID(),
        studentID: UUID,
        title: String,
        day: String,
        courseID: UUID? = nil,
        assignmentID: UUID? = nil,
        activityID: UUID? = nil,
        imageFileName: String,
        notes: String? = nil
    ) {
        self.id = id
        self.studentID = studentID
        self.title = title
        self.day = day
        self.courseID = courseID
        self.assignmentID = assignmentID
        self.activityID = activityID
        self.imageFileName = imageFileName
        self.notes = notes
    }
}

public enum BookFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case physical = "Physical Book"
    case audiobook = "Audiobook"
    case ebook = "E-Book"
    case readAloud = "Read Aloud"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .physical: return "book.closed"
        case .audiobook: return "headphones"
        case .ebook: return "ipad.and.iphone"
        case .readAloud: return "person.2.wave.2"
        }
    }
}

public enum BookStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case wantToRead = "Want to Read"
    case reading = "Currently Reading"
    case completed = "Completed"
    case abandoned = "Did Not Finish"

    public var id: String { rawValue }
}

public struct BookEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var studentID: UUID
    public var title: String
    public var author: String
    public var genre: String?
    public var isbn: String?
    public var format: BookFormat
    public var status: BookStatus
    public var totalPages: Int?
    public var currentPage: Int?
    public var rating: Int?
    public var notes: String?
    public var startDay: String?
    public var completedDay: String?
    public var academicYearID: UUID?

    public init(
        id: UUID = UUID(),
        studentID: UUID,
        title: String,
        author: String,
        genre: String? = nil,
        isbn: String? = nil,
        format: BookFormat = .physical,
        status: BookStatus = .reading,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        startDay: String? = nil,
        completedDay: String? = nil,
        academicYearID: UUID? = nil
    ) {
        self.id = id
        self.studentID = studentID
        self.title = title
        self.author = author
        self.genre = genre
        self.isbn = isbn
        self.format = format
        self.status = status
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.rating = rating
        self.notes = notes
        self.startDay = startDay
        self.completedDay = completedDay
        self.academicYearID = academicYearID
    }
}

public struct ReadingLogEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var bookID: UUID
    public var studentID: UUID
    public var day: String
    public var minutes: Int
    public var pagesRead: Int?
    public var notes: String?
    public var activityID: UUID?

    public init(
        id: UUID = UUID(),
        bookID: UUID,
        studentID: UUID,
        day: String,
        minutes: Int,
        pagesRead: Int? = nil,
        notes: String? = nil,
        activityID: UUID? = nil
    ) {
        self.id = id
        self.bookID = bookID
        self.studentID = studentID
        self.day = day
        self.minutes = minutes
        self.pagesRead = pagesRead
        self.notes = notes
        self.activityID = activityID
    }
}

// MARK: - Grade Categories

public struct GradeCategory: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var courseID: UUID
    public var name: String
    /// Fraction of the course grade (0.001 – 1.0). All categories for a course should sum to ≤ 1.0.
    public var weight: Double

    public init(
        id: UUID = UUID(),
        courseID: UUID,
        name: String,
        weight: Double
    ) {
        self.id = id
        self.courseID = courseID
        self.name = name
        self.weight = weight
    }
}

public struct PacedRescheduleResult: Codable, Equatable, Sendable {
    public let rescheduledCount: Int
    public let affectedCoursesCount: Int
    public let newCompletionDay: String?

    public init(rescheduledCount: Int, affectedCoursesCount: Int, newCompletionDay: String?) {
        self.rescheduledCount = rescheduledCount
        self.affectedCoursesCount = affectedCoursesCount
        self.newCompletionDay = newCompletionDay
    }
}

public struct StateCompliancePreset: Codable, Equatable, Sendable, Identifiable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let defaultDays: Int
    public let defaultHours: Int?
    public let regulatorySummary: String

    public init(
        code: String,
        name: String,
        defaultDays: Int,
        defaultHours: Int? = nil,
        regulatorySummary: String
    ) {
        self.code = code
        self.name = name
        self.defaultDays = defaultDays
        self.defaultHours = defaultHours
        self.regulatorySummary = regulatorySummary
    }

    public static func preset(for code: String) -> StateCompliancePreset? {
        allStates.first { $0.code.uppercased() == code.uppercased() }
    }

    public static let allStates: [StateCompliancePreset] = [
        StateCompliancePreset(code: "AL", name: "Alabama", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days standard instructional benchmark."),
        StateCompliancePreset(code: "AK", name: "Alaska", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; homeschools operate with high autonomy."),
        StateCompliancePreset(code: "AZ", name: "Arizona", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; affidavit of intent required within 30 days."),
        StateCompliancePreset(code: "AR", name: "Arkansas", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days standard benchmark; annual notice of intent."),
        StateCompliancePreset(code: "CA", name: "California", defaultDays: 175, defaultHours: nil, regulatorySummary: "175 days required under private school affidavit option."),
        StateCompliancePreset(code: "CO", name: "Colorado", defaultDays: 172, defaultHours: 688, regulatorySummary: "172 days with an average of 4 hours/day (688 total hours)."),
        StateCompliancePreset(code: "CT", name: "Connecticut", defaultDays: 180, defaultHours: 900, regulatorySummary: "180 days equivalent instruction in reading, writing, spelling, math, geography, history, and citizenship."),
        StateCompliancePreset(code: "DE", name: "Delaware", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days attendance tracking required for non-public school reporting."),
        StateCompliancePreset(code: "DC", name: "District of Columbia", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of thorough, regular education in required subject areas."),
        StateCompliancePreset(code: "FL", name: "Florida", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days or equivalent; annual portfolio evaluation required."),
        StateCompliancePreset(code: "GA", name: "Georgia", defaultDays: 180, defaultHours: 810, regulatorySummary: "180 days equivalent with at least 4.5 hours per school day."),
        StateCompliancePreset(code: "HI", name: "Hawaii", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; annual progress reports submitted to local school."),
        StateCompliancePreset(code: "ID", name: "Idaho", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; comparable instruction to public school offerings."),
        StateCompliancePreset(code: "IL", name: "Illinois", defaultDays: 176, defaultHours: nil, regulatorySummary: "176 days standard public school benchmark; instruction in required branches."),
        StateCompliancePreset(code: "IN", name: "Indiana", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of instruction required; attendance records must be kept."),
        StateCompliancePreset(code: "IA", name: "Iowa", defaultDays: 148, defaultHours: nil, regulatorySummary: "148 days of instruction required under independent private instruction options."),
        StateCompliancePreset(code: "KS", name: "Kansas", defaultDays: 186, defaultHours: 1116, regulatorySummary: "186 days (or 1,116 hours) required under non-accredited private school laws."),
        StateCompliancePreset(code: "KY", name: "Kentucky", defaultDays: 180, defaultHours: 1062, regulatorySummary: "180 days or 1,062 hours of instruction required in core subjects."),
        StateCompliancePreset(code: "LA", name: "Louisiana", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days required under registered home study or non-public school options."),
        StateCompliancePreset(code: "ME", name: "Maine", defaultDays: 175, defaultHours: nil, regulatorySummary: "175 days of instruction required; annual assessment submission."),
        StateCompliancePreset(code: "MD", name: "Maryland", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; regular thorough instruction verified by portfolio reviews."),
        StateCompliancePreset(code: "MA", name: "Massachusetts", defaultDays: 180, defaultHours: 900, regulatorySummary: "180 days or 900 hours (elementary) / 990 hours (secondary)."),
        StateCompliancePreset(code: "MI", name: "Michigan", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days standard benchmark; organized educational program in core subjects."),
        StateCompliancePreset(code: "MN", name: "Minnesota", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; instruction in required subjects with annual norm testing."),
        StateCompliancePreset(code: "MS", name: "Mississippi", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; certificate of enrollment submitted annually."),
        StateCompliancePreset(code: "MO", name: "Missouri", defaultDays: 180, defaultHours: 1000, regulatorySummary: "1,000 hours of instruction (at least 600 hours in core academic subjects)."),
        StateCompliancePreset(code: "MT", name: "Montana", defaultDays: 180, defaultHours: 720, regulatorySummary: "720 hours (grades 1–3) or 1,080 hours (grades 4–12) per year."),
        StateCompliancePreset(code: "NE", name: "Nebraska", defaultDays: 180, defaultHours: 1032, regulatorySummary: "1,032 hours (elementary) or 1,080 hours (high school) under Rule 13."),
        StateCompliancePreset(code: "NV", name: "Nevada", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; one-time notification of intent with educational plan."),
        StateCompliancePreset(code: "NH", name: "New Hampshire", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; annual evaluation or standardized test required."),
        StateCompliancePreset(code: "NJ", name: "New Jersey", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; instruction equivalent to that given in public schools."),
        StateCompliancePreset(code: "NM", name: "New Mexico", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of instruction required; annual notification to state department."),
        StateCompliancePreset(code: "NY", name: "New York", defaultDays: 180, defaultHours: 900, regulatorySummary: "180 days or 900 hours (grades 1–6) / 990 hours (grades 7–12); quarterly reporting."),
        StateCompliancePreset(code: "NC", name: "North Carolina", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of regular instruction required; annual nationally standardized testing."),
        StateCompliancePreset(code: "ND", name: "North Dakota", defaultDays: 175, defaultHours: 700, regulatorySummary: "175 days with minimum 4 hours/day (700 hours total); annual assessment."),
        StateCompliancePreset(code: "OH", name: "Ohio", defaultDays: 180, defaultHours: 900, regulatorySummary: "900 hours of instruction per school year; annual notification."),
        StateCompliancePreset(code: "OK", name: "Oklahoma", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of instruction required under constitutional homeschooling clause."),
        StateCompliancePreset(code: "OR", name: "Oregon", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; notification and standardized testing in grades 3, 5, 8, 10."),
        StateCompliancePreset(code: "PA", name: "Pennsylvania", defaultDays: 180, defaultHours: 900, regulatorySummary: "180 days or 900 hours (elementary) / 990 hours (secondary); annual evaluator review."),
        StateCompliancePreset(code: "RI", name: "Rhode Island", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of attendance and instruction required; approved by local school committee."),
        StateCompliancePreset(code: "SC", name: "South Carolina", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of instruction required under Option 1, 2, or 3 homeschool associations."),
        StateCompliancePreset(code: "SD", name: "South Dakota", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days equivalent; public school exemption notification filed with district."),
        StateCompliancePreset(code: "TN", name: "Tennessee", defaultDays: 180, defaultHours: 720, regulatorySummary: "180 days with at least 4 hours per day (720 total hours) for independent homeschools."),
        StateCompliancePreset(code: "TX", name: "Texas", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; bona fide curriculum covering math, reading, spelling, grammar, and citizenship."),
        StateCompliancePreset(code: "UT", name: "Utah", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days recommended; signed affidavit of parental responsibility filed with district."),
        StateCompliancePreset(code: "VT", name: "Vermont", defaultDays: 175, defaultHours: nil, regulatorySummary: "175 days recommended; annual home study enrollment notice and assessment."),
        StateCompliancePreset(code: "VA", name: "Virginia", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days standard benchmark; annual proof of academic progress due August 1."),
        StateCompliancePreset(code: "WA", name: "Washington", defaultDays: 180, defaultHours: 1000, regulatorySummary: "180 days or 1,000 hours of instruction required; annual assessment required."),
        StateCompliancePreset(code: "WV", name: "West Virginia", defaultDays: 180, defaultHours: nil, regulatorySummary: "180 days of instruction required; annual assessment results maintained."),
        StateCompliancePreset(code: "WI", name: "Wisconsin", defaultDays: 180, defaultHours: 875, regulatorySummary: "875 hours of instruction required; sequential progressive curriculum."),
        StateCompliancePreset(code: "WY", name: "Wyoming", defaultDays: 175, defaultHours: nil, regulatorySummary: "175 days of sequential education program in basic academic subjects.")
    ]
}

public enum SchoolStateError: LocalizedError, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidValue(String)
    case unknownStudent(UUID)
    case unknownAssignment(UUID)
    case unknownCourse(UUID)
    case unknownLesson(UUID)
    case unknownAttendance(UUID)
    case unknownActivity(UUID)
    case unknownAcademicYear(UUID)
    case unknownAcademicTerm(UUID)
    case unknownPortfolioItem(UUID)
    case unknownBook(UUID)
    case unknownReadingLog(UUID)
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
        case .unknownCourse:
            return "That course no longer exists. Refresh the plan and try again."
        case .unknownLesson:
            return "That lesson no longer exists. Refresh the plan and try again."
        case .unknownAttendance:
            return "That attendance record no longer exists. Refresh records and try again."
        case .unknownActivity:
            return "That activity no longer exists. Refresh records and try again."
        case .unknownAcademicYear:
            return "That academic year no longer exists. Refresh records and try again."
        case .unknownAcademicTerm:
            return "That term no longer exists. Refresh records and try again."
        case .unknownPortfolioItem:
            return "That portfolio work sample no longer exists. Refresh records and try again."
        case .unknownBook:
            return "That book no longer exists. Refresh the reading log and try again."
        case .unknownReadingLog:
            return "That reading log entry no longer exists. Refresh the reading log and try again."
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
    public var academicYears: [AcademicYear]
    public var terms: [AcademicTerm]
    public var activeYearID: UUID?
    public var parentPIN: String?
    public var selectedStateCode: String?
    public var portfolioItems: [PortfolioItem]
    public var books: [BookEntry]
    public var readingLogs: [ReadingLogEntry]
    public var gradeCategories: [GradeCategory]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case students
        case courses
        case lessons
        case assignments
        case attendance
        case activities
        case academicYears
        case terms
        case activeYearID
        case parentPIN
        case selectedStateCode
        case portfolioItems
        case books
        case readingLogs
        case gradeCategories
    }

    public init(
        schemaVersion: Int = 1,
        students: [Student] = [],
        courses: [Course] = [],
        lessons: [Lesson] = [],
        assignments: [Assignment] = [],
        attendance: [AttendanceEntry] = [],
        activities: [LearningActivity] = [],
        academicYears: [AcademicYear] = [],
        terms: [AcademicTerm] = [],
        activeYearID: UUID? = nil,
        parentPIN: String? = nil,
        selectedStateCode: String? = nil,
        portfolioItems: [PortfolioItem] = [],
        books: [BookEntry] = [],
        readingLogs: [ReadingLogEntry] = [],
        gradeCategories: [GradeCategory] = []
    ) {
        self.schemaVersion = schemaVersion
        self.students = students
        self.courses = courses
        self.lessons = lessons
        self.assignments = assignments
        self.attendance = attendance
        self.activities = activities
        self.academicYears = academicYears
        self.terms = terms
        self.activeYearID = activeYearID
        self.parentPIN = parentPIN
        self.selectedStateCode = selectedStateCode
        self.portfolioItems = portfolioItems
        self.books = books
        self.readingLogs = readingLogs
        self.gradeCategories = gradeCategories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.students = try container.decode([Student].self, forKey: .students)
        self.courses = try container.decode([Course].self, forKey: .courses)
        self.lessons = try container.decode([Lesson].self, forKey: .lessons)
        self.assignments = try container.decode([Assignment].self, forKey: .assignments)
        self.attendance = try container.decode([AttendanceEntry].self, forKey: .attendance)
        self.activities = try container.decode([LearningActivity].self, forKey: .activities)
        self.academicYears = try container.decodeIfPresent([AcademicYear].self, forKey: .academicYears) ?? []
        self.terms = try container.decodeIfPresent([AcademicTerm].self, forKey: .terms) ?? []
        self.activeYearID = try container.decodeIfPresent(UUID.self, forKey: .activeYearID)
        self.parentPIN = try container.decodeIfPresent(String.self, forKey: .parentPIN)
        self.selectedStateCode = try container.decodeIfPresent(String.self, forKey: .selectedStateCode)
        self.portfolioItems = try container.decodeIfPresent([PortfolioItem].self, forKey: .portfolioItems) ?? []
        self.books = try container.decodeIfPresent([BookEntry].self, forKey: .books) ?? []
        self.readingLogs = try container.decodeIfPresent([ReadingLogEntry].self, forKey: .readingLogs) ?? []
        self.gradeCategories = try container.decodeIfPresent([GradeCategory].self, forKey: .gradeCategories) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(students, forKey: .students)
        try container.encode(courses, forKey: .courses)
        try container.encode(lessons, forKey: .lessons)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(attendance, forKey: .attendance)
        try container.encode(activities, forKey: .activities)
        try container.encode(academicYears, forKey: .academicYears)
        try container.encode(terms, forKey: .terms)
        try container.encodeIfPresent(activeYearID, forKey: .activeYearID)
        try container.encodeIfPresent(parentPIN, forKey: .parentPIN)
        try container.encodeIfPresent(selectedStateCode, forKey: .selectedStateCode)
        try container.encode(portfolioItems, forKey: .portfolioItems)
        try container.encode(books, forKey: .books)
        try container.encode(readingLogs, forKey: .readingLogs)
        try container.encode(gradeCategories, forKey: .gradeCategories)
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw SchoolStateError.unsupportedSchema(schemaVersion) }

        if let parentPIN {
            guard parentPIN.count == 4 && parentPIN.allSatisfy(\.isNumber) else {
                throw SchoolStateError.invalidValue("Parent PIN must be exactly 4 numeric digits.")
            }
        }

        try validateUniqueIDs(students.map(\.id), collection: "students")
        try validateUniqueIDs(courses.map(\.id), collection: "courses")
        try validateUniqueIDs(lessons.map(\.id), collection: "lessons")
        try validateUniqueIDs(assignments.map(\.id), collection: "assignments")
        try validateUniqueIDs(attendance.map(\.id), collection: "attendance")
        try validateUniqueIDs(activities.map(\.id), collection: "activities")
        try validateUniqueIDs(academicYears.map(\.id), collection: "academic years")
        try validateUniqueIDs(terms.map(\.id), collection: "terms")
        try validateUniqueIDs(portfolioItems.map(\.id), collection: "portfolio items")
        try validateUniqueIDs(books.map(\.id), collection: "books")
        try validateUniqueIDs(readingLogs.map(\.id), collection: "reading logs")

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
            if let credits = course.creditHours {
                guard credits >= 0 && credits <= 10 else {
                    throw SchoolStateError.invalidValue("Course credit hours must be between 0 and 10.")
                }
            }
            if let weight = course.weight {
                guard weight >= 0 && weight <= 10 else {
                    throw SchoolStateError.invalidValue("Course weight must be between 0 and 10.")
                }
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
            if let grade = assignment.grade {
                guard grade >= 0 && grade <= 100 else {
                    throw SchoolStateError.invalidValue("Assignment grade must be between 0 and 100 percent.")
                }
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

        let academicYearIDs = Set(academicYears.map(\.id))
        for year in academicYears {
            try validateRequiredText(year.title, field: "Academic year title")
            try validateDay(year.startDay)
            try validateDay(year.endDay)
            guard year.startDay < year.endDay else {
                throw SchoolStateError.invalidValue("Academic year start date must precede end date.")
            }
            guard year.targetDays > 0 && year.targetDays <= 365 else {
                throw SchoolStateError.invalidValue("Target school days must be between 1 and 365.")
            }
            if let hours = year.targetHours {
                guard hours > 0 && hours <= 3000 else {
                    throw SchoolStateError.invalidValue("Target instructional hours must be between 1 and 3000.")
                }
            }
        }

        for term in terms {
            guard academicYearIDs.contains(term.academicYearID) else {
                throw SchoolStateError.danglingReference("A term refers to a missing academic year")
            }
            try validateRequiredText(term.title, field: "Term title")
            try validateDay(term.startDay)
            try validateDay(term.endDay)
            guard term.startDay < term.endDay else {
                throw SchoolStateError.invalidValue("Term start date must precede end date.")
            }
        }

        if let activeYearID {
            guard academicYearIDs.contains(activeYearID) else {
                throw SchoolStateError.danglingReference("Active academic year refers to a missing year")
            }
        }

        let assignmentIDs = Set(assignments.map(\.id))
        let activityIDs = Set(activities.map(\.id))
        for item in portfolioItems {
            guard studentIDs.contains(item.studentID) else {
                throw SchoolStateError.danglingReference("A portfolio item refers to a missing student")
            }
            try validateRequiredText(item.title, field: "Portfolio item title")
            try validateDay(item.day)
            try validateRequiredText(item.imageFileName, field: "Portfolio item image")
            if let courseID = item.courseID {
                guard courseIDs.contains(courseID) else {
                    throw SchoolStateError.danglingReference("A portfolio item refers to a missing course")
                }
            }
            if let assignmentID = item.assignmentID {
                guard assignmentIDs.contains(assignmentID) else {
                    throw SchoolStateError.danglingReference("A portfolio item refers to a missing assignment")
                }
            }
            if let activityID = item.activityID {
                guard activityIDs.contains(activityID) else {
                    throw SchoolStateError.danglingReference("A portfolio item refers to a missing activity")
                }
            }
        }

        let bookIDs = Set(books.map(\.id))
        for book in books {
            guard studentIDs.contains(book.studentID) else {
                throw SchoolStateError.danglingReference("A book refers to a missing student")
            }
            try validateRequiredText(book.title, field: "Book title")
            try validateRequiredText(book.author, field: "Book author")
            if let totalPages = book.totalPages {
                guard totalPages >= 0 else {
                    throw SchoolStateError.invalidValue("Total pages cannot be negative.")
                }
            }
            if let currentPage = book.currentPage {
                guard currentPage >= 0 else {
                    throw SchoolStateError.invalidValue("Current page cannot be negative.")
                }
            }
            if let rating = book.rating {
                guard (1...5).contains(rating) else {
                    throw SchoolStateError.invalidValue("Rating must be between 1 and 5.")
                }
            }
            if let startDay = book.startDay {
                try validateDay(startDay)
            }
            if let completedDay = book.completedDay {
                try validateDay(completedDay)
            }
            if let academicYearID = book.academicYearID {
                guard academicYearIDs.contains(academicYearID) else {
                    throw SchoolStateError.danglingReference("A book refers to a missing academic year")
                }
            }
        }

        for log in readingLogs {
            guard studentIDs.contains(log.studentID) else {
                throw SchoolStateError.danglingReference("A reading log refers to a missing student")
            }
            guard bookIDs.contains(log.bookID) else {
                throw SchoolStateError.danglingReference("A reading log refers to a missing book")
            }
            guard log.minutes > 0 else {
                throw SchoolStateError.invalidValue("Reading minutes must be greater than zero.")
            }
            if let pagesRead = log.pagesRead {
                guard pagesRead >= 0 else {
                    throw SchoolStateError.invalidValue("Pages read cannot be negative.")
                }
            }
            try validateDay(log.day)
            if let activityID = log.activityID {
                guard activityIDs.contains(activityID) else {
                    throw SchoolStateError.danglingReference("A reading log refers to a missing activity")
                }
            }
        }

        try validateUniqueIDs(gradeCategories.map(\.id), collection: "grade categories")
        var categoryWeightSums: [UUID: Double] = [:]
        for category in gradeCategories {
            guard courseIDs.contains(category.courseID) else {
                throw SchoolStateError.danglingReference("A grade category refers to a missing course")
            }
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw SchoolStateError.invalidValue("Grade category name cannot be blank.")
            }
            guard category.weight > 0 && category.weight <= 1.0 else {
                throw SchoolStateError.invalidValue("Grade category weight must be between 0.001 and 1.0.")
            }
            categoryWeightSums[category.courseID, default: 0] += category.weight
        }
        for (_, sum) in categoryWeightSums {
            guard sum <= 1.001 else {
                throw SchoolStateError.invalidValue("Grade category weights for a course must not exceed 100% in total.")
            }
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

    public mutating func updateStudent(id: UUID, name: String, gradeLevel: String) throws {
        try validate()
        guard let index = students.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownStudent(id)
        }
        let cleanedName = try cleanedRequiredText(name, field: "Student name")
        let cleanedGradeLevel = try cleanedRequiredText(gradeLevel, field: "Grade level")
        students[index].name = cleanedName
        students[index].gradeLevel = cleanedGradeLevel
        try validate()
    }

    public mutating func deleteStudent(id: UUID) throws {
        try validate()
        guard let index = students.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownStudent(id)
        }
        students.remove(at: index)
        assignments.removeAll { $0.studentID == id }
        attendance.removeAll { $0.studentID == id }
        activities.removeAll { $0.studentID == id }
        portfolioItems.removeAll { $0.studentID == id }
        books.removeAll { $0.studentID == id }
        readingLogs.removeAll { $0.studentID == id }
        try validate()
    }

    public mutating func updateCourse(id: UUID, title: String) throws {
        try validate()
        guard let index = courses.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownCourse(id)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Course title")
        courses[index].title = cleanedTitle
        try validate()
    }

    public mutating func deleteCourse(id: UUID) throws {
        try validate()
        guard let index = courses.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownCourse(id)
        }
        courses.remove(at: index)
        let courseLessonIDs = Set(lessons.filter { $0.courseID == id }.map(\.id))
        let courseAssignmentIDs = Set(assignments.filter { courseLessonIDs.contains($0.lessonID) }.map(\.id))
        lessons.removeAll { $0.courseID == id }
        assignments.removeAll { courseLessonIDs.contains($0.lessonID) }
        for i in portfolioItems.indices {
            if portfolioItems[i].courseID == id {
                portfolioItems[i].courseID = nil
            }
            if let aid = portfolioItems[i].assignmentID, courseAssignmentIDs.contains(aid) {
                portfolioItems[i].assignmentID = nil
            }
        }
        // Remove grade categories belonging to this course.
        gradeCategories.removeAll { $0.courseID == id }
        try validate()
    }

    public mutating func updateLesson(id: UUID, title: String) throws {
        try validate()
        guard let index = lessons.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownLesson(id)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Lesson title")
        lessons[index].title = cleanedTitle
        try validate()
    }

    public mutating func deleteLesson(id: UUID) throws {
        try validate()
        guard let index = lessons.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownLesson(id)
        }
        let courseID = lessons[index].courseID
        let lessonAssignmentIDs = Set(assignments.filter { $0.lessonID == id }.map(\.id))
        lessons.remove(at: index)
        assignments.removeAll { $0.lessonID == id }
        for i in portfolioItems.indices {
            if let aid = portfolioItems[i].assignmentID, lessonAssignmentIDs.contains(aid) {
                portfolioItems[i].assignmentID = nil
            }
        }

        // Re-index remaining lessons for this course to keep sequences contiguous 1, 2, 3...
        let courseLessons = lessons.filter { $0.courseID == courseID }.sorted { $0.sequence < $1.sequence }
        for (newSeq, lesson) in courseLessons.enumerated() {
            if let originalIndex = lessons.firstIndex(where: { $0.id == lesson.id }) {
                lessons[originalIndex].sequence = newSeq + 1
            }
        }
        try validate()
    }

    @discardableResult
    public mutating func addLesson(courseID: UUID, title: String) throws -> UUID {
        try validate()
        guard courses.contains(where: { $0.id == courseID }) else {
            throw SchoolStateError.unknownCourse(courseID)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Lesson title")
        let existingLessons = lessons.filter { $0.courseID == courseID }
        guard existingLessons.count < 365 else {
            throw SchoolStateError.invalidValue("A course may contain at most 365 lessons.")
        }
        let nextSequence = (existingLessons.map(\.sequence).max() ?? 0) + 1
        let newLesson = Lesson(courseID: courseID, title: cleanedTitle, sequence: nextSequence)
        lessons.append(newLesson)

        // Find students enrolled in this course (students who have assignments for this course)
        let existingLessonIDs = Set(existingLessons.map(\.id))
        let enrolledStudentIDs = Set(assignments.filter { existingLessonIDs.contains($0.lessonID) }.map(\.studentID))
        for studentID in enrolledStudentIDs {
            assignments.append(Assignment(studentID: studentID, lessonID: newLesson.id))
        }
        try validate()
        return newLesson.id
    }

    public mutating func reorderLessons(courseID: UUID, lessonIDsInOrder: [UUID]) throws {
        try validate()
        guard courses.contains(where: { $0.id == courseID }) else {
            throw SchoolStateError.unknownCourse(courseID)
        }
        let currentCourseLessons = lessons.filter { $0.courseID == courseID }
        let currentLessonIDs = Set(currentCourseLessons.map(\.id))
        guard lessonIDsInOrder.count == currentCourseLessons.count,
              Set(lessonIDsInOrder) == currentLessonIDs else {
            throw SchoolStateError.invalidValue("All lessons for this course must be provided in the reordered list.")
        }
        for (index, lessonID) in lessonIDsInOrder.enumerated() {
            if let lessonIndex = lessons.firstIndex(where: { $0.id == lessonID }) {
                lessons[lessonIndex].sequence = index + 1
            }
        }
        try validate()
    }

    public mutating func updateAttendance(id: UUID, day: String? = nil, minutes: Int) throws {
        try validate()
        guard let index = attendance.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAttendance(id)
        }
        try validateMinutes(minutes, allowed: 1...1440)
        let targetDay = day ?? attendance[index].day
        try validateDay(targetDay)

        let studentID = attendance[index].studentID
        if attendance.contains(where: { $0.id != id && $0.studentID == studentID && $0.day == targetDay }) {
            throw SchoolStateError.duplicateAttendance(studentID, targetDay)
        }

        attendance[index].day = targetDay
        attendance[index].minutes = minutes
        try validate()
    }

    public mutating func deleteAttendance(id: UUID) throws {
        try validate()
        guard let index = attendance.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAttendance(id)
        }
        attendance.remove(at: index)
        try validate()
    }

    public mutating func updateActivity(id: UUID, title: String, day: String, minutes: Int) throws {
        try validate()
        guard let index = activities.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownActivity(id)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Activity title")
        try validateDay(day)
        try validateMinutes(minutes, allowed: 0...1440)

        activities[index].title = cleanedTitle
        activities[index].day = day
        activities[index].minutes = minutes
        try validate()
    }

    public mutating func deleteActivity(id: UUID) throws {
        try validate()
        guard let index = activities.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownActivity(id)
        }
        activities.remove(at: index)
        for i in portfolioItems.indices {
            if portfolioItems[i].activityID == id {
                portfolioItems[i].activityID = nil
            }
        }
        for i in readingLogs.indices {
            if readingLogs[i].activityID == id {
                readingLogs[i].activityID = nil
            }
        }
        try validate()
    }

    public static func defaultAcademicYear(for date: Date = Date()) -> AcademicYear {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = gregorian.component(.year, from: date)
        let month = gregorian.component(.month, from: date)
        let startYear = month >= 7 ? year : year - 1
        let endYear = startYear + 1
        return AcademicYear(
            title: "\(startYear)–\(endYear)",
            startDay: String(format: "%04d-08-01", startYear),
            endDay: String(format: "%04d-06-30", endYear),
            targetDays: 180,
            targetHours: 900
        )
    }

    public func resolvedActiveAcademicYear(for date: Date = Date()) -> AcademicYear {
        if let activeYearID, let year = academicYears.first(where: { $0.id == activeYearID }) {
            return year
        }
        let todayStr = SchoolDay.string(from: date)
        if let yearForToday = academicYears.first(where: { $0.contains(day: todayStr) }) {
            return yearForToday
        }
        if let first = academicYears.first {
            return first
        }
        return Self.defaultAcademicYear(for: date)
    }

    @discardableResult
    public mutating func addAcademicYear(
        title: String,
        startDay: String,
        endDay: String,
        targetDays: Int = 180,
        targetHours: Int? = nil,
        makeActive: Bool = false
    ) throws -> UUID {
        try validate()
        let cleanedTitle = try cleanedRequiredText(title, field: "Academic year title")
        try validateDay(startDay)
        try validateDay(endDay)
        guard startDay < endDay else {
            throw SchoolStateError.invalidValue("Academic year start date must precede end date.")
        }
        guard targetDays > 0 && targetDays <= 365 else {
            throw SchoolStateError.invalidValue("Target school days must be between 1 and 365.")
        }
        if let targetHours {
            guard targetHours > 0 && targetHours <= 3000 else {
                throw SchoolStateError.invalidValue("Target instructional hours must be between 1 and 3000.")
            }
        }
        let year = AcademicYear(
            title: cleanedTitle,
            startDay: startDay,
            endDay: endDay,
            targetDays: targetDays,
            targetHours: targetHours
        )
        academicYears.append(year)
        if makeActive || activeYearID == nil {
            activeYearID = year.id
        }
        try validate()
        return year.id
    }

    public mutating func updateAcademicYear(
        id: UUID,
        title: String,
        startDay: String,
        endDay: String,
        targetDays: Int,
        targetHours: Int?
    ) throws {
        try validate()
        guard let index = academicYears.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAcademicYear(id)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Academic year title")
        try validateDay(startDay)
        try validateDay(endDay)
        guard startDay < endDay else {
            throw SchoolStateError.invalidValue("Academic year start date must precede end date.")
        }
        guard targetDays > 0 && targetDays <= 365 else {
            throw SchoolStateError.invalidValue("Target school days must be between 1 and 365.")
        }
        if let targetHours {
            guard targetHours > 0 && targetHours <= 3000 else {
                throw SchoolStateError.invalidValue("Target instructional hours must be between 1 and 3000.")
            }
        }
        academicYears[index].title = cleanedTitle
        academicYears[index].startDay = startDay
        academicYears[index].endDay = endDay
        academicYears[index].targetDays = targetDays
        academicYears[index].targetHours = targetHours
        try validate()
    }

    public mutating func deleteAcademicYear(id: UUID) throws {
        try validate()
        guard let index = academicYears.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAcademicYear(id)
        }
        academicYears.remove(at: index)
        terms.removeAll { $0.academicYearID == id }
        for i in books.indices {
            if books[i].academicYearID == id {
                books[i].academicYearID = nil
            }
        }
        if activeYearID == id {
            activeYearID = academicYears.first?.id
        }
        try validate()
    }

    public mutating func setActiveAcademicYear(id: UUID?) throws {
        try validate()
        if let id {
            guard academicYears.contains(where: { $0.id == id }) else {
                throw SchoolStateError.unknownAcademicYear(id)
            }
        }
        activeYearID = id
        try validate()
    }

    @discardableResult
    public mutating func addTerm(
        yearID: UUID,
        title: String,
        startDay: String,
        endDay: String
    ) throws -> UUID {
        try validate()
        guard academicYears.contains(where: { $0.id == yearID }) else {
            throw SchoolStateError.unknownAcademicYear(yearID)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Term title")
        try validateDay(startDay)
        try validateDay(endDay)
        guard startDay < endDay else {
            throw SchoolStateError.invalidValue("Term start date must precede end date.")
        }
        let term = AcademicTerm(academicYearID: yearID, title: cleanedTitle, startDay: startDay, endDay: endDay)
        terms.append(term)
        try validate()
        return term.id
    }

    public mutating func deleteTerm(id: UUID) throws {
        try validate()
        guard let index = terms.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAcademicTerm(id)
        }
        terms.remove(at: index)
        try validate()
    }

    public func attendance(for studentID: UUID? = nil, in year: AcademicYear) -> [AttendanceEntry] {
        attendance.filter { entry in
            (studentID == nil || entry.studentID == studentID) && year.contains(day: entry.day)
        }
    }

    public func activities(for studentID: UUID? = nil, in year: AcademicYear) -> [LearningActivity] {
        activities.filter { activity in
            (studentID == nil || activity.studentID == studentID) && year.contains(day: activity.day)
        }
    }

    public func completedAssignments(for studentID: UUID? = nil, in year: AcademicYear) -> [Assignment] {
        assignments.filter { assignment in
            guard assignment.status == .completed, let completedDay = assignment.completedDay else { return false }
            return (studentID == nil || assignment.studentID == studentID) && year.contains(day: completedDay)
        }
    }

    public mutating func setParentPIN(_ pin: String?) throws {
        if let pin {
            let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count == 4 && trimmed.allSatisfy(\.isNumber) else {
                throw SchoolStateError.invalidValue("Parent PIN must be exactly 4 numeric digits.")
            }
            parentPIN = trimmed
        } else {
            parentPIN = nil
        }
        try validate()
    }

    public func verifyParentPIN(_ pin: String) -> Bool {
        guard let parentPIN else { return true }
        return parentPIN == pin.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func setSelectedStateCode(_ code: String?) throws {
        if let code {
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !trimmed.isEmpty else {
                selectedStateCode = nil
                try validate()
                return
            }
            guard StateCompliancePreset.preset(for: trimmed) != nil else {
                throw SchoolStateError.invalidValue("Unknown US state code: \(trimmed)")
            }
            selectedStateCode = trimmed
        } else {
            selectedStateCode = nil
        }
        try validate()
    }

    public mutating func setAssignmentGrade(id: UUID, grade: Double?, notes: String? = nil) throws {
        try validate()
        guard let index = assignments.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAssignment(id)
        }
        if let grade {
            guard grade >= 0 && grade <= 100 else {
                throw SchoolStateError.invalidValue("Assignment grade must be between 0 and 100 percent.")
            }
        }
        assignments[index].grade = grade
        if let notes {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            assignments[index].notes = trimmed.isEmpty ? nil : trimmed
        }
        try validate()
    }

    public mutating func setAssignmentCategory(id: UUID, categoryID: UUID?) throws {
        try validate()
        guard let index = assignments.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownAssignment(id)
        }
        if let categoryID {
            guard gradeCategories.contains(where: { $0.id == categoryID }) else {
                throw SchoolStateError.invalidValue("That grade category no longer exists.")
            }
        }
        assignments[index].categoryID = categoryID
        try validate()
    }

    public mutating func updateCourseCredits(id: UUID, creditHours: Double?, weight: Double?) throws {
        try validate()
        guard let index = courses.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownCourse(id)
        }
        if let creditHours {
            guard creditHours >= 0 && creditHours <= 10 else {
                throw SchoolStateError.invalidValue("Course credit hours must be between 0 and 10.")
            }
        }
        if let weight {
            guard weight >= 0 && weight <= 10 else {
                throw SchoolStateError.invalidValue("Course weight must be between 0 and 10.")
            }
        }
        courses[index].creditHours = creditHours
        courses[index].weight = weight
        try validate()
    }

    public func courseGrade(for studentID: UUID, courseID: UUID) -> Double? {
        let courseLessonIDs = Set(lessons.filter { $0.courseID == courseID }.map(\.id))
        let studentAssignments = assignments.filter { $0.studentID == studentID && courseLessonIDs.contains($0.lessonID) }
        let courseCategories = gradeCategories.filter { $0.courseID == courseID }

        // If no grade categories defined, fall back to simple average.
        guard !courseCategories.isEmpty else {
            let graded = studentAssignments.compactMap(\.grade)
            guard !graded.isEmpty else { return nil }
            return graded.reduce(0, +) / Double(graded.count)
        }

        // Weighted category average.
        var weightedSum: Double = 0
        var totalWeight: Double = 0
        for category in courseCategories {
            let categoryAssignments = studentAssignments.filter { $0.categoryID == category.id }
            let graded = categoryAssignments.compactMap(\.grade)
            guard !graded.isEmpty else { continue }
            let avg = graded.reduce(0, +) / Double(graded.count)
            weightedSum += avg * category.weight
            totalWeight += category.weight
        }

        // Also include any assignments not in a category (weight them as uncategorized).
        let categorizedIDs = Set(courseCategories.map(\.id))
        let uncategorized = studentAssignments.filter { $0.categoryID == nil || !categorizedIDs.contains($0.categoryID!) }
        let uncategorizedGraded = uncategorized.compactMap(\.grade)
        let remainingWeight = max(0, 1.0 - totalWeight)
        if !uncategorizedGraded.isEmpty && remainingWeight > 0 {
            let avg = uncategorizedGraded.reduce(0, +) / Double(uncategorizedGraded.count)
            weightedSum += avg * remainingWeight
            totalWeight += remainingWeight
        }

        guard totalWeight > 0 else { return nil }
        return weightedSum / totalWeight
    }

    /// Returns the average grade for all graded assignments belonging to a specific grade category and student.
    public func categoryGrade(for studentID: UUID, categoryID: UUID) -> Double? {
        let graded = assignments.filter { $0.studentID == studentID && $0.categoryID == categoryID }.compactMap(\.grade)
        guard !graded.isEmpty else { return nil }
        return graded.reduce(0, +) / Double(graded.count)
    }

    public func courseCreditsEarned(for studentID: UUID, courseID: UUID) -> Double {
        guard let course = courses.first(where: { $0.id == courseID }),
              let credits = course.creditHours,
              credits > 0 else {
            return 0.0
        }
        guard let grade = courseGrade(for: studentID, courseID: courseID) else {
            return 0.0
        }
        return grade >= 65.0 ? credits : 0.0
    }

    public func cumulativeGPA(for studentID: UUID, weighted: Bool) -> Double? {
        let studentAssignmentLessonIDs = Set(assignments.filter { $0.studentID == studentID }.map(\.lessonID))
        let studentCourseIDs = Set(lessons.filter { studentAssignmentLessonIDs.contains($0.id) }.map(\.courseID))

        var totalWeightedPoints: Double = 0
        var totalCredits: Double = 0
        var courseCount: Int = 0
        var totalUnweightedPointsWithoutCredits: Double = 0

        for courseID in studentCourseIDs {
            guard let grade = courseGrade(for: studentID, courseID: courseID),
                  let course = courses.first(where: { $0.id == courseID }) else {
                continue
            }
            let basePoint: Double
            switch grade {
            case 93...: basePoint = 4.0
            case 90..<93: basePoint = 3.7
            case 87..<90: basePoint = 3.3
            case 83..<87: basePoint = 3.0
            case 80..<83: basePoint = 2.7
            case 77..<80: basePoint = 2.3
            case 73..<77: basePoint = 2.0
            case 70..<73: basePoint = 1.7
            case 65..<70: basePoint = 1.0
            default: basePoint = 0.0
            }

            let courseWeight = course.weight ?? 4.0
            let weightAddition = weighted && courseWeight > 4.0 ? (courseWeight - 4.0) : 0.0
            let finalPoint = min(basePoint + weightAddition, 5.0)

            let credits = course.creditHours ?? 1.0
            totalWeightedPoints += finalPoint * credits
            totalCredits += credits
            courseCount += 1
            totalUnweightedPointsWithoutCredits += basePoint
        }

        guard totalCredits > 0 else {
            return courseCount > 0 ? (totalUnweightedPointsWithoutCredits / Double(courseCount)) : nil
        }
        return totalWeightedPoints / totalCredits
    }

    @discardableResult
    public mutating func rescheduleOverduePaced(
        from startDay: String,
        studentID: UUID? = nil,
        weekdays: Set<Int> = [2, 3, 4, 5, 6]
    ) throws -> PacedRescheduleResult {
        try validate()
        try validateDay(startDay)
        guard !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }) else {
            throw SchoolStateError.invalidValue("Paced rescheduling requires one or more weekdays numbered 1 through 7.")
        }

        let targetStudents: [Student]
        if let studentID {
            guard let s = students.first(where: { $0.id == studentID }) else {
                throw SchoolStateError.unknownStudent(studentID)
            }
            targetStudents = [s]
        } else {
            targetStudents = students
        }

        var totalRescheduled = 0
        var affectedCourses = Set<UUID>()
        var maxNewDay: String? = nil

        let lessonMap = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })

        for student in targetStudents {
            let studentAssignments = assignments.filter { $0.studentID == student.id }
            let overdueAssignments = studentAssignments.filter {
                guard let scheduledDay = $0.scheduledDay else { return false }
                return scheduledDay < startDay && $0.status != .completed && $0.status != .skipped
            }

            if overdueAssignments.isEmpty { continue }

            let coursesWithOverdue = Set(overdueAssignments.compactMap { lessonMap[$0.lessonID]?.courseID })

            for courseID in coursesWithOverdue {
                affectedCourses.insert(courseID)

                let courseAssignments = studentAssignments.filter { assignment in
                    guard let lesson = lessonMap[assignment.lessonID], lesson.courseID == courseID else { return false }
                    guard assignment.status != .completed && assignment.status != .skipped else { return false }
                    return assignment.scheduledDay != nil
                }

                let sortedCourseAssignments = courseAssignments.sorted { a1, a2 in
                    let seq1 = lessonMap[a1.lessonID]?.sequence ?? 0
                    let seq2 = lessonMap[a2.lessonID]?.sequence ?? 0
                    return seq1 < seq2
                }

                let newDays = try scheduledDaysFrom(startDay: startDay, count: sortedCourseAssignments.count, weekdays: weekdays)

                for (index, assignment) in sortedCourseAssignments.enumerated() {
                    let targetDay = newDays[index]
                    if let assignmentIndex = assignments.firstIndex(where: { $0.id == assignment.id }) {
                        if assignments[assignmentIndex].scheduledDay != targetDay {
                            assignments[assignmentIndex].scheduledDay = targetDay
                            totalRescheduled += 1
                        }
                        if let targetDay {
                            if maxNewDay == nil || targetDay > maxNewDay! {
                                maxNewDay = targetDay
                            }
                        }
                    }
                }
            }
        }

        try validate()
        return PacedRescheduleResult(
            rescheduledCount: totalRescheduled,
            affectedCoursesCount: affectedCourses.count,
            newCompletionDay: maxNewDay
        )
    }

    @discardableResult
    public mutating func addPortfolioItem(
        studentID: UUID,
        title: String,
        day: String,
        courseID: UUID? = nil,
        assignmentID: UUID? = nil,
        activityID: UUID? = nil,
        imageFileName: String,
        notes: String? = nil
    ) throws -> UUID {
        try validate()
        guard students.contains(where: { $0.id == studentID }) else {
            throw SchoolStateError.unknownStudent(studentID)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Portfolio item title")
        try validateDay(day)
        let cleanedImageFileName = try cleanedRequiredText(imageFileName, field: "Portfolio item image")
        if let courseID {
            guard courses.contains(where: { $0.id == courseID }) else {
                throw SchoolStateError.unknownCourse(courseID)
            }
        }
        if let assignmentID {
            guard assignments.contains(where: { $0.id == assignmentID }) else {
                throw SchoolStateError.unknownAssignment(assignmentID)
            }
        }
        if let activityID {
            guard activities.contains(where: { $0.id == activityID }) else {
                throw SchoolStateError.unknownActivity(activityID)
            }
        }
        let item = PortfolioItem(
            studentID: studentID,
            title: cleanedTitle,
            day: day,
            courseID: courseID,
            assignmentID: assignmentID,
            activityID: activityID,
            imageFileName: cleanedImageFileName,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
        portfolioItems.append(item)
        try validate()
        return item.id
    }

    public mutating func updatePortfolioItem(
        id: UUID,
        title: String,
        day: String? = nil,
        notes: String? = nil
    ) throws {
        try validate()
        guard let index = portfolioItems.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownPortfolioItem(id)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Portfolio item title")
        if let day {
            try validateDay(day)
            portfolioItems[index].day = day
        }
        portfolioItems[index].title = cleanedTitle
        portfolioItems[index].notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        try validate()
    }

    public mutating func deletePortfolioItem(id: UUID) throws {
        try validate()
        guard let index = portfolioItems.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownPortfolioItem(id)
        }
        portfolioItems.remove(at: index)
        try validate()
    }

    public func portfolioItems(
        for studentID: UUID? = nil,
        courseID: UUID? = nil,
        in year: AcademicYear? = nil
    ) -> [PortfolioItem] {
        portfolioItems.filter { item in
            if let studentID, item.studentID != studentID { return false }
            if let courseID, item.courseID != courseID { return false }
            if let year, !year.contains(day: item.day) { return false }
            return true
        }.sorted { $0.day > $1.day }
    }

    // MARK: - Book & Reading Log Operations

    @discardableResult
    public mutating func addBook(
        studentID: UUID,
        title: String,
        author: String,
        genre: String? = nil,
        isbn: String? = nil,
        format: BookFormat = .physical,
        status: BookStatus = .reading,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        startDay: String? = nil,
        completedDay: String? = nil,
        academicYearID: UUID? = nil
    ) throws -> UUID {
        try validate()
        guard students.contains(where: { $0.id == studentID }) else {
            throw SchoolStateError.unknownStudent(studentID)
        }
        let cleanedTitle = try cleanedRequiredText(title, field: "Book title")
        let cleanedAuthor = try cleanedRequiredText(author, field: "Book author")
        if let totalPages {
            guard totalPages >= 0 else { throw SchoolStateError.invalidValue("Total pages cannot be negative.") }
        }
        if let currentPage {
            guard currentPage >= 0 else { throw SchoolStateError.invalidValue("Current page cannot be negative.") }
        }
        if let rating {
            guard (1...5).contains(rating) else { throw SchoolStateError.invalidValue("Rating must be between 1 and 5.") }
        }
        if let startDay {
            try validateDay(startDay)
        }
        if let completedDay {
            try validateDay(completedDay)
        }
        if let academicYearID {
            guard academicYears.contains(where: { $0.id == academicYearID }) else {
                throw SchoolStateError.unknownAcademicYear(academicYearID)
            }
        }

        let book = BookEntry(
            studentID: studentID,
            title: cleanedTitle,
            author: cleanedAuthor,
            genre: genre?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? genre?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            isbn: isbn?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? isbn?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            format: format,
            status: status,
            totalPages: totalPages,
            currentPage: currentPage,
            rating: rating,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            startDay: startDay,
            completedDay: completedDay,
            academicYearID: academicYearID
        )
        books.append(book)
        try validate()
        return book.id
    }

    public mutating func updateBook(
        id: UUID,
        title: String? = nil,
        author: String? = nil,
        genre: String? = nil,
        isbn: String? = nil,
        format: BookFormat? = nil,
        status: BookStatus? = nil,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        startDay: String? = nil,
        completedDay: String? = nil,
        academicYearID: UUID? = nil
    ) throws {
        try validate()
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownBook(id)
        }

        if let title {
            books[index].title = try cleanedRequiredText(title, field: "Book title")
        }
        if let author {
            books[index].author = try cleanedRequiredText(author, field: "Book author")
        }
        if let genre {
            books[index].genre = genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : genre.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let isbn {
            let trimmed = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
            books[index].isbn = trimmed.isEmpty ? nil : trimmed
        }
        if let format {
            books[index].format = format
        }
        if let status {
            books[index].status = status
        }
        if let totalPages {
            guard totalPages >= 0 else { throw SchoolStateError.invalidValue("Total pages cannot be negative.") }
            books[index].totalPages = totalPages
        }
        if let currentPage {
            guard currentPage >= 0 else { throw SchoolStateError.invalidValue("Current page cannot be negative.") }
            books[index].currentPage = currentPage
        }
        if let rating {
            guard (1...5).contains(rating) else { throw SchoolStateError.invalidValue("Rating must be between 1 and 5.") }
            books[index].rating = rating
        }
        if let notes {
            books[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let startDay {
            try validateDay(startDay)
            books[index].startDay = startDay
        }
        if let completedDay {
            try validateDay(completedDay)
            books[index].completedDay = completedDay
        }
        if let academicYearID {
            guard academicYears.contains(where: { $0.id == academicYearID }) else {
                throw SchoolStateError.unknownAcademicYear(academicYearID)
            }
            books[index].academicYearID = academicYearID
        }
        try validate()
    }

    public mutating func deleteBook(id: UUID) throws {
        try validate()
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownBook(id)
        }
        books.remove(at: index)
        readingLogs.removeAll { $0.bookID == id }
        try validate()
    }

    // MARK: - Grade Category Mutations

    @discardableResult
    public mutating func addGradeCategory(courseID: UUID, name: String, weight: Double) throws -> UUID {
        try validate()
        guard courses.contains(where: { $0.id == courseID }) else {
            throw SchoolStateError.unknownCourse(courseID)
        }
        let cleanedName = try cleanedRequiredText(name, field: "Grade category name")
        guard weight > 0 && weight <= 1.0 else {
            throw SchoolStateError.invalidValue("Grade category weight must be between 0.001 and 1.0.")
        }
        let existing = gradeCategories.filter { $0.courseID == courseID }
        let newSum = existing.reduce(0) { $0 + $1.weight } + weight
        guard newSum <= 1.001 else {
            throw SchoolStateError.invalidValue("Adding this category would cause the total weight to exceed 100% for this course.")
        }
        let category = GradeCategory(courseID: courseID, name: cleanedName, weight: weight)
        gradeCategories.append(category)
        try validate()
        return category.id
    }

    public mutating func updateGradeCategory(id: UUID, name: String? = nil, weight: Double? = nil) throws {
        try validate()
        guard let index = gradeCategories.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.invalidValue("That grade category no longer exists.")
        }
        if let name {
            gradeCategories[index].name = try cleanedRequiredText(name, field: "Grade category name")
        }
        if let weight {
            guard weight > 0 && weight <= 1.0 else {
                throw SchoolStateError.invalidValue("Grade category weight must be between 0.001 and 1.0.")
            }
            let courseID = gradeCategories[index].courseID
            let othersSum = gradeCategories.enumerated()
                .filter { $0.offset != index && $0.element.courseID == courseID }
                .reduce(0) { $0 + $1.element.weight }
            guard othersSum + weight <= 1.001 else {
                throw SchoolStateError.invalidValue("Updating this weight would cause the total to exceed 100% for this course.")
            }
            gradeCategories[index].weight = weight
        }
        try validate()
    }

    public mutating func deleteGradeCategory(id: UUID) throws {
        try validate()
        guard let index = gradeCategories.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.invalidValue("That grade category no longer exists.")
        }
        gradeCategories.remove(at: index)
        // Clear categoryID on any assignments that referenced this category.
        for i in assignments.indices where assignments[i].categoryID == id {
            assignments[i].categoryID = nil
        }
        try validate()
    }

    @discardableResult
    public mutating func addReadingLogEntry(
        bookID: UUID,
        studentID: UUID,
        day: String,
        minutes: Int,
        pagesRead: Int? = nil,
        notes: String? = nil,
        logToAttendance: Bool = false
    ) throws -> UUID {
        try validate()
        guard let book = books.first(where: { $0.id == bookID }) else {
            throw SchoolStateError.unknownBook(bookID)
        }
        guard students.contains(where: { $0.id == studentID }) else {
            throw SchoolStateError.unknownStudent(studentID)
        }
        try validateDay(day)
        guard minutes > 0 else {
            throw SchoolStateError.invalidValue("Reading minutes must be greater than zero.")
        }
        if let pagesRead {
            guard pagesRead >= 0 else {
                throw SchoolStateError.invalidValue("Pages read cannot be negative.")
            }
        }

        var linkedActivityID: UUID? = nil
        if logToAttendance {
            let activityTitle = "Reading: \(book.title)"
            let activity = LearningActivity(studentID: studentID, title: activityTitle, day: day, minutes: minutes)
            activities.append(activity)
            linkedActivityID = activity.id
        }

        if let pagesRead, let current = book.currentPage {
            if let bookIndex = books.firstIndex(where: { $0.id == bookID }) {
                let updatedPages = current + pagesRead
                books[bookIndex].currentPage = updatedPages
                if let total = books[bookIndex].totalPages, updatedPages >= total {
                    books[bookIndex].status = .completed
                    if books[bookIndex].completedDay == nil {
                        books[bookIndex].completedDay = day
                    }
                }
            }
        }

        let entry = ReadingLogEntry(
            bookID: bookID,
            studentID: studentID,
            day: day,
            minutes: minutes,
            pagesRead: pagesRead,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            activityID: linkedActivityID
        )
        readingLogs.append(entry)
        try validate()
        return entry.id
    }

    public mutating func deleteReadingLogEntry(id: UUID) throws {
        try validate()
        guard let index = readingLogs.firstIndex(where: { $0.id == id }) else {
            throw SchoolStateError.unknownReadingLog(id)
        }
        let entry = readingLogs[index]
        readingLogs.remove(at: index)
        if let actID = entry.activityID {
            activities.removeAll { $0.id == actID }
        }
        try validate()
    }

    public func books(
        for studentID: UUID? = nil,
        status: BookStatus? = nil,
        in year: AcademicYear? = nil
    ) -> [BookEntry] {
        books.filter { book in
            if let studentID, book.studentID != studentID { return false }
            if let status, book.status != status { return false }
            if let year {
                if let yid = book.academicYearID {
                    return yid == year.id
                }
                if let comp = book.completedDay {
                    return year.contains(day: comp)
                }
                if let start = book.startDay {
                    return year.contains(day: start)
                }
            }
            return true
        }
    }

    public func readingLogs(
        for studentID: UUID? = nil,
        bookID: UUID? = nil,
        in year: AcademicYear? = nil
    ) -> [ReadingLogEntry] {
        readingLogs.filter { log in
            if let studentID, log.studentID != studentID { return false }
            if let bookID, log.bookID != bookID { return false }
            if let year, !year.contains(day: log.day) { return false }
            return true
        }.sorted { $0.day > $1.day }
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

    public static func nextDay(from string: String) -> String? {
        guard let date = try? date(from: string) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return SchoolDay.string(from: next, calendar: calendar)
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

public enum HomeschoolCalendarGenerator {
    public static func generateICS(
        state: SchoolState,
        studentID: UUID? = nil,
        academicYear: AcademicYear? = nil
    ) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//HomeschoolEZ//Homeschool Calendar 1.0//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH"
        ]

        let studentLookup = Dictionary(uniqueKeysWithValues: state.students.map { ($0.id, $0) })
        let courseLookup = Dictionary(uniqueKeysWithValues: state.courses.map { ($0.id, $0) })
        let lessonLookup = Dictionary(uniqueKeysWithValues: state.lessons.map { ($0.id, $0) })

        // 1. Academic Terms
        for term in state.terms {
            if let academicYear, term.academicYearID != academicYear.id { continue }
            guard let startDate = icsDate(term.startDay),
                  let nextEndDate = icsNextDate(term.endDay) else { continue }
            lines.append("BEGIN:VEVENT")
            lines.append("UID:term-\(term.id.uuidString)@homeschoolhelper")
            lines.append("DTSTAMP:\(icsTimestamp())")
            lines.append("DTSTART;VALUE=DATE:\(startDate)")
            lines.append("DTEND;VALUE=DATE:\(nextEndDate)")
            lines.append("SUMMARY:\(escapeICS(term.title))")
            lines.append("DESCRIPTION:\(escapeICS("Academic Term: \(term.title)"))")
            lines.append("STATUS:CONFIRMED")
            lines.append("TRANSP:TRANSPARENT")
            lines.append("END:VEVENT")
        }

        // 2. Scheduled Assignments
        let relevantAssignments = state.assignments.filter { assignment in
            guard let day = assignment.scheduledDay else { return false }
            if let studentID, assignment.studentID != studentID { return false }
            if let academicYear, !academicYear.contains(day: day) { return false }
            return true
        }

        for assignment in relevantAssignments {
            guard let day = assignment.scheduledDay,
                  let startDate = icsDate(day),
                  let nextDate = icsNextDate(day),
                  let lesson = lessonLookup[assignment.lessonID] else { continue }

            let student = studentLookup[assignment.studentID]
            let course = courseLookup[lesson.courseID]
            let studentName = student?.name ?? "Student"
            let courseTitle = course?.title ?? "Course"
            let summary = "\(courseTitle): \(lesson.title) (\(studentName))"
            var desc = "Lesson: \(lesson.title)\nCourse: \(courseTitle)\nStudent: \(studentName)\nStatus: \(assignment.status.rawValue.capitalized)"
            if let grade = assignment.grade {
                desc += "\nGrade: \(Int(round(grade)))%"
            }

            lines.append("BEGIN:VEVENT")
            lines.append("UID:assignment-\(assignment.id.uuidString)@homeschoolhelper")
            lines.append("DTSTAMP:\(icsTimestamp())")
            lines.append("DTSTART;VALUE=DATE:\(startDate)")
            lines.append("DTEND;VALUE=DATE:\(nextDate)")
            lines.append("SUMMARY:\(escapeICS(summary))")
            lines.append("DESCRIPTION:\(escapeICS(desc))")
            lines.append("STATUS:\(assignment.status == .completed ? "CONFIRMED" : "TENTATIVE")")
            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func icsDate(_ day: String) -> String? {
        guard SchoolDay.isValid(day) else { return nil }
        return day.replacingOccurrences(of: "-", with: "")
    }

    private static func icsNextDate(_ day: String) -> String? {
        guard let next = SchoolDay.nextDay(from: day) else { return nil }
        return icsDate(next)
    }

    private static func icsTimestamp() -> String {
        return "20260101T000000Z"
    }

    private static func escapeICS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}
