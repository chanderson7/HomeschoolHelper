import Foundation
import SwiftUI
import HomeschoolCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif
import UniformTypeIdentifiers

// MARK: - Export Models

public enum ReportType: String, CaseIterable, Identifiable {
    case attendance = "Attendance & Hours Log"
    case curriculum = "Curriculum Progress Report"
    case chronicle = "Comprehensive Annual Chronicle"
    case transcript = "Official High School Transcript"
    case reportCard = "Academic Report Card"
    case readingLog = "Reading Log & Book List"
    case calendar = "Calendar Schedule (.ics)"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .attendance:
            return "calendar.badge.clock"
        case .curriculum:
            return "book.closed"
        case .chronicle:
            return "doc.richtext"
        case .transcript:
            return "graduationcap"
        case .reportCard:
            return "chart.bar.doc.horizontal"
        case .readingLog:
            return "books.vertical"
        case .calendar:
            return "calendar"
        }
    }

    public var summary: String {
        switch self {
        case .attendance:
            return "Official daily attendance log, cumulative hours, state compliance target, and parent legal signature line."
        case .curriculum:
            return "Course progress breakdown, completed lessons, planned syllabus, and mastery pacing."
        case .chronicle:
            return "Comprehensive portfolio chronicle combining attendance, curriculum pacing, extracurricular activities, and certification."
        case .transcript:
            return "Official academic high school transcript with Carnegie credit hours, letter grades, cumulative GPA, and parent certification."
        case .reportCard:
            return "Official academic report card with weighted subject grades, category breakdown, GPA summary, and parent educator certification."
        case .readingLog:
            return "Official reading log and book list with titles, authors, genres, completion dates, ratings, and instructional reading hours for state portfolio evaluations."
        case .calendar:
            return "Standard RFC 5545 iCalendar schedule (.ics) of scheduled lessons and academic terms for Apple Calendar, Google Calendar, and Microsoft Outlook."
        }
    }
}

public enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF Document"
    case csv = "CSV Spreadsheet"
    case ics = "iCalendar (.ics)"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .csv: return "csv"
        case .ics: return "ics"
        }
    }

    public var utType: UTType {
        switch self {
        case .pdf: return .pdf
        case .csv: return .commaSeparatedText
        case .ics:
            if let custom = UTType(filenameExtension: "ics") {
                return custom
            }
            return .text
        }
    }
}

public struct ExportedReportFile: Identifiable {
    public let id = UUID()
    public let fileName: String
    public let data: Data
    public let format: ExportFormat
    public let fileURL: URL

    public init(fileName: String, data: Data, format: ExportFormat) throws {
        self.fileName = fileName
        self.data = data
        self.format = format

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeschoolExports", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let destination = tempDir.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        self.fileURL = destination
    }
}

// MARK: - CSV Generation Engine (RFC 4180)

public enum HomeschoolCSVGenerator {
    private static func escapeField(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }

    private static func formatRow(_ fields: [String]) -> String {
        fields.map(escapeField).joined(separator: ",")
    }

    public static func generateAttendanceCSV(
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> String {
        var lines: [String] = []

        // Header Comments / Metadata
        lines.append(formatRow(["HOMESCHOOL COMPASS - OFFICIAL ATTENDANCE & HOURS LOG"]))
        lines.append(formatRow(["Academic Year", year.title, "Dates", "\(year.startDay) to \(year.endDay)"]))
        if let student {
            lines.append(formatRow(["Student", student.name, "Grade", student.gradeLevel]))
        } else {
            lines.append(formatRow(["Scope", "All Students (Household)"]))
        }
        lines.append(formatRow(["Target Days", "\(year.targetDays)"]))
        if let targetHours = year.targetHours {
            lines.append(formatRow(["Target Hours", "\(targetHours)"]))
        }
        lines.append("")

        // Table Header
        lines.append(formatRow(["Date", "Student", "Grade", "Minutes", "Hours"]))

        let entries = state.attendance(for: student?.id, in: year).sorted { $0.day < $1.day }
        var totalMinutes = 0
        var uniqueDays = Set<String>()

        for entry in entries {
            let entryStudent = state.students.first { $0.id == entry.studentID }
            let studentName = entryStudent?.name ?? "Student"
            let grade = entryStudent?.gradeLevel ?? ""
            let hours = String(format: "%.2f", Double(entry.minutes) / 60.0)
            lines.append(formatRow([entry.day, studentName, grade, "\(entry.minutes)", hours]))
            totalMinutes += entry.minutes
            uniqueDays.insert(entry.day)
        }

        lines.append("")
        lines.append(formatRow(["--- COMPLIANCE SUMMARY ---"]))
        lines.append(formatRow(["Total Days Attended", "\(uniqueDays.count)"]))
        lines.append(formatRow(["Target Days", "\(year.targetDays)"]))
        let daysMet = uniqueDays.count >= year.targetDays ? "YES" : "IN PROGRESS"
        lines.append(formatRow(["Days Target Met", daysMet]))
        lines.append(formatRow(["Total Instructional Hours", String(format: "%.2f", Double(totalMinutes) / 60.0)]))
        if let targetHours = year.targetHours {
            let hoursMet = (totalMinutes / 60) >= targetHours ? "YES" : "IN PROGRESS"
            lines.append(formatRow(["Target Hours", "\(targetHours)"]))
            lines.append(formatRow(["Hours Target Met", hoursMet]))
        }

        return lines.joined(separator: "\r\n")
    }

    public static func generateCurriculumCSV(
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> String {
        var lines: [String] = []

        lines.append(formatRow(["HOMESCHOOL COMPASS - CURRICULUM PROGRESS REPORT"]))
        lines.append(formatRow(["Academic Year", year.title]))
        if let student {
            lines.append(formatRow(["Student", student.name, "Grade", student.gradeLevel]))
        } else {
            lines.append(formatRow(["Scope", "All Students (Household)"]))
        }
        lines.append("")

        lines.append(formatRow(["Course", "Student", "Lesson #", "Lesson Title", "Status", "Scheduled Date", "Completed Date"]))

        let targetStudents = student != nil ? [student!] : state.students
        for st in targetStudents {
            let studentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentLessonIDs.contains($0.id) }.map(\.courseID))
            let studentCourses = state.courses.filter { studentCourseIDs.contains($0.id) }
            let studentAssignments = state.assignments.filter { $0.studentID == st.id }

            for course in studentCourses {
                let courseLessons = state.lessons.filter { $0.courseID == course.id }.sorted { $0.sequence < $1.sequence }

                for lesson in courseLessons {
                    let assignment = studentAssignments.first { $0.lessonID == lesson.id }
                    let status = assignment?.status.rawValue.capitalized ?? "Planned"
                    let scheduled = assignment?.scheduledDay ?? ""
                    let completed = assignment?.completedDay ?? ""
                    lines.append(formatRow([
                        course.title,
                        st.name,
                        "\(lesson.sequence)",
                        lesson.title,
                        status,
                        scheduled,
                        completed
                    ]))
                }
            }
        }

        return lines.joined(separator: "\r\n")
    }

    public static func generateChronicleCSV(
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> String {
        var lines: [String] = []

        lines.append(formatRow(["HOMESCHOOL COMPASS - COMPREHENSIVE ANNUAL CHRONICLE"]))
        lines.append(formatRow(["Academic Year", year.title, "Range", "\(year.startDay) to \(year.endDay)"]))
        if let student {
            lines.append(formatRow(["Student", student.name, "Grade", student.gradeLevel]))
        } else {
            lines.append(formatRow(["Scope", "Household (All Students)"]))
        }
        lines.append("")

        // Section 1: Attendance
        lines.append(formatRow(["--- ATTENDANCE LOG ---"]))
        lines.append(formatRow(["Date", "Student", "Minutes", "Hours"]))
        let entries = state.attendance(for: student?.id, in: year).sorted { $0.day < $1.day }
        for entry in entries {
            let st = state.students.first { $0.id == entry.studentID }
            let hours = String(format: "%.2f", Double(entry.minutes) / 60.0)
            lines.append(formatRow([entry.day, st?.name ?? "Student", "\(entry.minutes)", hours]))
        }
        lines.append("")

        // Section 2: Learning Activities
        lines.append(formatRow(["--- LEARNING ACTIVITIES & FIELD TRIPS ---"]))
        lines.append(formatRow(["Date", "Student", "Activity", "Minutes", "Hours"]))
        let activities = state.activities(for: student?.id, in: year).sorted { $0.day < $1.day }
        for act in activities {
            let st = state.students.first { $0.id == act.studentID }
            let hours = String(format: "%.2f", Double(act.minutes) / 60.0)
            lines.append(formatRow([act.day, st?.name ?? "Student", act.title, "\(act.minutes)", hours]))
        }
        lines.append("")

        // Section 3: Curriculum summary
        lines.append(formatRow(["--- CURRICULUM SUMMARY ---"]))
        lines.append(formatRow(["Course", "Student", "Total Lessons", "Completed", "Pacing %"]))
        let targetStudents = student != nil ? [student!] : state.students
        for st in targetStudents {
            let studentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentLessonIDs.contains($0.id) }.map(\.courseID))
            let studentCourses = state.courses.filter { studentCourseIDs.contains($0.id) }
            let studentAssignments = state.assignments.filter { $0.studentID == st.id }
            let completedLessonIDs = Set(studentAssignments.filter { $0.status == .completed }.map(\.lessonID))

            for course in studentCourses {
                let courseLessons = state.lessons.filter { $0.courseID == course.id }
                let completedCount = courseLessons.filter { completedLessonIDs.contains($0.id) }.count
                let total = courseLessons.count
                let pct = total > 0 ? "\(Int((Double(completedCount) / Double(total)) * 100))%" : "0%"
                lines.append(formatRow([course.title, st.name, "\(total)", "\(completedCount)", pct]))
            }
        }

        return lines.joined(separator: "\r\n")
    }

    public static func generateTranscriptCSV(
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> String {
        var lines: [String] = []

        lines.append(formatRow(["HOMESCHOOL COMPASS - OFFICIAL HIGH SCHOOL ACADEMIC TRANSCRIPT"]))
        lines.append(formatRow(["Academic Year", year.title]))
        if let student {
            lines.append(formatRow(["Student", student.name, "Grade", student.gradeLevel]))
            let unweighted = state.cumulativeGPA(for: student.id, weighted: false)
            let weighted = state.cumulativeGPA(for: student.id, weighted: true)
            let unweightedStr = unweighted != nil ? String(format: "%.2f", unweighted!) : "N/A"
            let weightedStr = weighted != nil ? String(format: "%.2f", weighted!) : "N/A"
            lines.append(formatRow(["Cumulative GPA (Unweighted)", unweightedStr]))
            lines.append(formatRow(["Cumulative GPA (Weighted)", weightedStr]))
        } else {
            lines.append(formatRow(["Scope", "All Students (Household)"]))
        }
        lines.append("")

        lines.append(formatRow(["Course Title", "Student", "Weight", "Credits Attempted", "Credits Earned", "Average Grade (%)", "Letter Grade"]))

        let targetStudents = student != nil ? [student!] : state.students
        for st in targetStudents {
            let studentAssignmentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentAssignmentLessonIDs.contains($0.id) }.map(\.courseID))
            let studentCourses = state.courses.filter { studentCourseIDs.contains($0.id) }

            for course in studentCourses {
                let creditAttempted = course.creditHours ?? 1.0
                let creditEarned = state.courseCreditsEarned(for: st.id, courseID: course.id)
                let grade = state.courseGrade(for: st.id, courseID: course.id)
                let gradeStr = grade != nil ? String(format: "%.1f%%", grade!) : "In Progress"
                let letterGrade: String
                if let grade {
                    switch grade {
                    case 97...: letterGrade = "A+"
                    case 93..<97: letterGrade = "A"
                    case 90..<93: letterGrade = "A-"
                    case 87..<90: letterGrade = "B+"
                    case 83..<87: letterGrade = "B"
                    case 80..<83: letterGrade = "B-"
                    case 77..<80: letterGrade = "C+"
                    case 73..<77: letterGrade = "C"
                    case 70..<73: letterGrade = "C-"
                    case 65..<70: letterGrade = "D"
                    default: letterGrade = "F"
                    }
                } else {
                    letterGrade = "—"
                }
                let weightStr = String(format: "%.1f", course.weight ?? 4.0)

                lines.append(formatRow([
                    course.title,
                    st.name,
                    weightStr,
                    String(format: "%.2f", creditAttempted),
                    String(format: "%.2f", creditEarned),
                    gradeStr,
                    letterGrade
                ]))
            }
        }

        return lines.joined(separator: "\r\n")
    }

    public static func generateReadingLogCSV(
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> String {
        var lines: [String] = []

        lines.append(formatRow(["HOMESCHOOL COMPASS - OFFICIAL READING LOG & BOOK LIST"]))
        lines.append(formatRow(["Academic Year", year.title]))
        if let student {
            lines.append(formatRow(["Student", student.name, "Grade", student.gradeLevel]))
        } else {
            lines.append(formatRow(["Scope", "All Students (Household)"]))
        }
        lines.append("")

        lines.append(formatRow([
            "Title",
            "Author",
            "Student",
            "Format",
            "Status",
            "Total Pages",
            "Pages Read",
            "Rating",
            "Start Date",
            "Completed Date",
            "Notes"
        ]))

        let books = state.books(for: student?.id, in: year)
        for book in books {
            let studentName = state.students.first(where: { $0.id == book.studentID })?.name ?? "Unknown"
            let ratingStr = book.rating != nil ? "\(book.rating!)/5 Stars" : "Unrated"
            lines.append(formatRow([
                book.title,
                book.author,
                studentName,
                book.format.rawValue,
                book.status.rawValue,
                book.totalPages != nil ? "\(book.totalPages!)" : "—",
                book.currentPage != nil ? "\(book.currentPage!)" : "—",
                ratingStr,
                book.startDay ?? "—",
                book.completedDay ?? "—",
                book.notes ?? ""
            ]))
        }

        lines.append("")
        lines.append(formatRow(["READING SESSION LOGS"]))
        lines.append(formatRow(["Date", "Book Title", "Student", "Minutes Read", "Pages Read", "Session Notes"]))

        let logs = state.readingLogs(for: student?.id, in: year)
        for log in logs {
            let studentName = state.students.first(where: { $0.id == log.studentID })?.name ?? "Unknown"
            let bookTitle = state.books.first(where: { $0.id == log.bookID })?.title ?? "Unknown"
            lines.append(formatRow([
                log.day,
                bookTitle,
                studentName,
                "\(log.minutes)",
                log.pagesRead != nil ? "\(log.pagesRead!)" : "—",
                log.notes ?? ""
            ]))
        }

        return lines.joined(separator: "\r\n")
    }

    public static func generateReportCardCSV(
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> String {
        var lines: [String] = []

        lines.append(formatRow(["HOMESCHOOL COMPASS - OFFICIAL ACADEMIC REPORT CARD"]))
        lines.append(formatRow(["Academic Year", year.title]))
        if let student {
            lines.append(formatRow(["Student", student.name, "Grade Level", student.gradeLevel]))
            let unweighted = state.cumulativeGPA(for: student.id, weighted: false)
            let weighted = state.cumulativeGPA(for: student.id, weighted: true)
            lines.append(formatRow(["Cumulative GPA (Unweighted)", unweighted != nil ? String(format: "%.2f", unweighted!) : "N/A"]))
            lines.append(formatRow(["Cumulative GPA (Weighted)", weighted != nil ? String(format: "%.2f", weighted!) : "N/A"]))
        } else {
            lines.append(formatRow(["Scope", "All Students (Household)"]))
        }
        lines.append("")

        lines.append(formatRow([
            "Student",
            "Grade Level",
            "Course Title",
            "Credit Hours",
            "Course Weight",
            "Category Breakdown",
            "Final Score %",
            "Letter Grade",
            "Credits Earned"
        ]))

        let targetStudents = student != nil ? [student!] : state.students
        for st in targetStudents {
            let studentAssignmentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentAssignmentLessonIDs.contains($0.id) }.map(\.courseID))
            let courses = state.courses.filter { studentCourseIDs.contains($0.id) }

            for course in courses {
                let credits = course.creditHours ?? 1.0
                let earned = state.courseCreditsEarned(for: st.id, courseID: course.id)
                let grade = state.courseGrade(for: st.id, courseID: course.id)
                let gradeStr = grade != nil ? String(format: "%.1f%%", grade!) : "In Progress"
                let letterGrade: String
                if let grade {
                    switch grade {
                    case 97...: letterGrade = "A+"
                    case 93..<97: letterGrade = "A"
                    case 90..<93: letterGrade = "A-"
                    case 87..<90: letterGrade = "B+"
                    case 83..<87: letterGrade = "B"
                    case 80..<83: letterGrade = "B-"
                    case 77..<80: letterGrade = "C+"
                    case 73..<77: letterGrade = "C"
                    case 70..<73: letterGrade = "C-"
                    case 65..<70: letterGrade = "D"
                    default: letterGrade = "F"
                    }
                } else {
                    letterGrade = "—"
                }

                let categories = state.gradeCategories.filter { $0.courseID == course.id }
                let catSummary = categories.map { cat in
                    let catAvg = state.categoryGrade(for: st.id, categoryID: cat.id)
                    let avgStr = catAvg != nil ? String(format: "%.0f%%", catAvg!) : "—"
                    return "\(cat.name) (\(Int(cat.weight * 100))%): \(avgStr)"
                }.joined(separator: "; ")

                lines.append(formatRow([
                    st.name,
                    st.gradeLevel,
                    course.title,
                    String(format: "%.2f", credits),
                    String(format: "%.2f", course.weight ?? 4.0),
                    catSummary.isEmpty ? "None" : catSummary,
                    gradeStr,
                    letterGrade,
                    String(format: "%.2f", earned)
                ]))
            }
        }

        return lines.joined(separator: "\r\n")
    }
}

// MARK: - PDF Generation Engine (Letter 8.5" x 11")

#if canImport(UIKit)
public enum HomeschoolPDFGenerator {
    // 8.5" x 11" at 72 dpi = 612 x 792 points
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 36
    private static let contentWidth: CGFloat = pageWidth - (margin * 2)
    private static let maxY: CGFloat = pageHeight - margin - 30 // reserve space for footer

    public static func generateReportPDF(
        type: ReportType,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Homeschool Compass",
            kCGPDFContextAuthor: "Homeschool Compass Official Records",
            kCGPDFContextTitle: "\(type.rawValue) - \(year.title)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        return renderer.pdfData { context in
            var pageIndex = 1
            context.beginPage()
            var currentY: CGFloat = margin

            func drawRunningHeader() {
                let headerFont = UIFont.systemFont(ofSize: 8, weight: .bold)
                let subFont = UIFont.systemFont(ofSize: 8, weight: .regular)
                let headerText = "HOMESCHOOL COMPASS — OFFICIAL ACADEMIC RECORD"
                let dateText = "Generated: \(Date().formatted(.dateTime.year().month().day()))"

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                (headerText as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: attributes)

                let rightAttributes: [NSAttributedString.Key: Any] = [
                    .font: subFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let rightSize = (dateText as NSString).size(withAttributes: rightAttributes)
                (dateText as NSString).draw(at: CGPoint(x: pageWidth - margin - rightSize.width, y: margin), withAttributes: rightAttributes)

                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: margin + 14))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: margin + 14))
                path.lineWidth = 0.5
                UIColor.separator.setStroke()
                path.stroke()
            }

            func drawRunningFooter() {
                let footerFont = UIFont.systemFont(ofSize: 8, weight: .regular)
                let footerText = "Official Documentation • Confidential School Record"
                let pageText = "Page \(pageIndex)"

                let leftAttr: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.tertiaryLabel]
                (footerText as NSString).draw(at: CGPoint(x: margin, y: pageHeight - margin + 8), withAttributes: leftAttr)

                let rightSize = (pageText as NSString).size(withAttributes: leftAttr)
                (pageText as NSString).draw(at: CGPoint(x: pageWidth - margin - rightSize.width, y: pageHeight - margin + 8), withAttributes: leftAttr)
            }

            func checkNewPage(neededHeight: CGFloat) {
                if currentY + neededHeight > maxY {
                    drawRunningFooter()
                    context.beginPage()
                    pageIndex += 1
                    currentY = margin + 24
                    drawRunningHeader()
                }
            }

            // Draw initial header
            drawRunningHeader()
            currentY += 24

            // Document Title
            let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
            let titleText = type.rawValue
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            (titleText as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
            currentY += 22

            // Metadata Sub-bar
            let metaFont = UIFont.systemFont(ofSize: 10, weight: .medium)
            let studentName = student?.name ?? "All Students (Household)"
            let grade = student != nil ? " • Grade \(student!.gradeLevel)" : ""
            let metaText = "Academic Year: \(year.title) (\(year.startDay) to \(year.endDay))  |  Student: \(studentName)\(grade)"
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: metaFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            (metaText as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: metaAttributes)
            currentY += 18

            // Compliance Summary Card
            currentY = drawComplianceSummaryBox(
                in: context,
                currentY: currentY,
                type: type,
                state: state,
                student: student,
                year: year
            )

            switch type {
            case .attendance:
                currentY = drawAttendanceSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawSignatureBlock(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage
                )

            case .curriculum:
                currentY = drawCurriculumSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )

            case .chronicle:
                currentY = drawAttendanceSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawActivitiesSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawCurriculumSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawSignatureBlock(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage
                )

            case .transcript:
                currentY = drawTranscriptSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawTranscriptSignatureBlock(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage
                )

            case .reportCard:
                currentY = drawReportCardSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawTranscriptSignatureBlock(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage
                )

            case .readingLog:
                currentY = drawReadingLogSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawSignatureBlock(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage
                )

            case .calendar:
                currentY = drawCurriculumSection(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage,
                    state: state,
                    student: student,
                    year: year
                )
                currentY = drawSignatureBlock(
                    in: context,
                    currentY: currentY,
                    checkNewPage: checkNewPage
                )
            }

            drawRunningFooter()
        }
    }

    private static func drawComplianceSummaryBox(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        type: ReportType,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        let boxRect = CGRect(x: margin, y: y, width: contentWidth, height: 50)
        let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 6)
        UIColor.systemGray6.setFill()
        boxPath.fill()

        UIColor.systemGray4.setStroke()
        boxPath.lineWidth = 0.5
        boxPath.stroke()

        if type == .readingLog {
            let totalBooks = state.books(for: student?.id, in: year).count
            let completed = state.books(for: student?.id, status: .completed, in: year).count
            let totalMinutes = state.readingLogs(for: student?.id, in: year).reduce(0) { $0 + $1.minutes }
            let hours = Double(totalMinutes) / 60.0

            let col1Rect = CGRect(x: margin + 12, y: y + 8, width: 160, height: 34)
            drawMetric(
                title: "TOTAL BOOKS",
                value: "\(totalBooks)",
                rect: col1Rect
            )

            let col2Rect = CGRect(x: margin + 180, y: y + 8, width: 160, height: 34)
            drawMetric(
                title: "BOOKS COMPLETED",
                value: "\(completed)",
                rect: col2Rect
            )

            let col3Rect = CGRect(x: margin + 350, y: y + 8, width: 170, height: 34)
            drawMetric(
                title: "READING TIME",
                value: String(format: "%.1f hrs (%d min)", hours, totalMinutes),
                rect: col3Rect,
                isHighlight: totalMinutes > 0
            )

            y += 60
            return y
        }

        if type == .transcript {
            let unweighted = student != nil ? state.cumulativeGPA(for: student!.id, weighted: false) : nil
            let weighted = student != nil ? state.cumulativeGPA(for: student!.id, weighted: true) : nil
            let unweightedStr = unweighted != nil ? String(format: "%.2f / 4.00", unweighted!) : "—"
            let weightedStr = weighted != nil ? String(format: "%.2f", weighted!) : "—"

            let targetStudents = student != nil ? [student!] : state.students
            var totalCredits: Double = 0
            for st in targetStudents {
                let stLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
                let stCourseIDs = Set(state.lessons.filter { stLessonIDs.contains($0.id) }.map(\.courseID))
                for cID in stCourseIDs {
                    totalCredits += state.courseCreditsEarned(for: st.id, courseID: cID)
                }
            }

            // Column 1: Unweighted GPA
            let col1Rect = CGRect(x: margin + 12, y: y + 8, width: 160, height: 34)
            drawMetric(
                title: "UNWEIGHTED GPA",
                value: unweightedStr,
                rect: col1Rect
            )

            // Column 2: Weighted GPA
            let col2Rect = CGRect(x: margin + 180, y: y + 8, width: 160, height: 34)
            drawMetric(
                title: "WEIGHTED GPA",
                value: weightedStr,
                rect: col2Rect
            )

            // Column 3: Credits Earned
            let col3Rect = CGRect(x: margin + 350, y: y + 8, width: 170, height: 34)
            drawMetric(
                title: "TOTAL CREDITS EARNED",
                value: String(format: "%.2f Credits", totalCredits),
                rect: col3Rect,
                isHighlight: totalCredits > 0
            )

            y += 60
            return y
        }

        let entries = state.attendance(for: student?.id, in: year)
        let daysCount = Set(entries.map(\.day)).count
        let totalMinutes = entries.reduce(0) { $0 + $1.minutes }
        let totalHours = Double(totalMinutes) / 60.0
        let daysPercent = year.targetDays > 0 ? Int((Double(daysCount) / Double(year.targetDays)) * 100) : 0

        // Column 1: Days
        let col1Rect = CGRect(x: margin + 12, y: y + 8, width: 160, height: 34)
        drawMetric(
            title: "ATTENDANCE DAYS",
            value: "\(daysCount) of \(year.targetDays) (\(daysPercent)%)",
            rect: col1Rect
        )

        // Column 2: Hours
        let col2Rect = CGRect(x: margin + 180, y: y + 8, width: 160, height: 34)
        let targetHoursStr = year.targetHours != nil ? " / \(year.targetHours!)" : ""
        drawMetric(
            title: "INSTRUCTIONAL HOURS",
            value: "\(String(format: "%.1f", totalHours)) hrs\(targetHoursStr)",
            rect: col2Rect
        )

        // Column 3: Status
        let col3Rect = CGRect(x: margin + 350, y: y + 8, width: 170, height: 34)
        let status = daysCount >= year.targetDays ? "COMPLIANCE MET" : "IN PROGRESS"
        drawMetric(
            title: "COMPLIANCE STATUS",
            value: status,
            rect: col3Rect,
            isHighlight: daysCount >= year.targetDays
        )

        y += 60
        return y
    }

    private static func drawMetric(title: String, value: String, rect: CGRect, isHighlight: Bool = false) {
        let titleFont = UIFont.systemFont(ofSize: 7, weight: .semibold)
        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.secondaryLabel]
        (title as NSString).draw(at: rect.origin, withAttributes: titleAttr)

        let valFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let color = isHighlight ? UIColor.systemGreen : UIColor.label
        let valAttr: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: color]
        (value as NSString).draw(at: CGPoint(x: rect.origin.x, y: rect.origin.y + 12), withAttributes: valAttr)
    }

    private static func drawAttendanceSection(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        checkNewPage(40)

        // Section Title
        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let sectionAttr: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: UIColor.label]
        ("Attendance & Instructional Hours Log" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttr)
        y += 18

        // Table Header
        let thFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let thAttr: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: UIColor.secondaryLabel]

        ("Date" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
        ("Student" as NSString).draw(at: CGPoint(x: margin + 110, y: y), withAttributes: thAttr)
        ("Minutes" as NSString).draw(at: CGPoint(x: margin + 300, y: y), withAttributes: thAttr)
        ("Hours" as NSString).draw(at: CGPoint(x: margin + 420, y: y), withAttributes: thAttr)
        y += 14

        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        line.lineWidth = 0.5
        UIColor.separator.setStroke()
        line.stroke()
        y += 4

        let entries = state.attendance(for: student?.id, in: year).sorted { $0.day < $1.day }
        let rowFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let rowAttr: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.label]

        if entries.isEmpty {
            ("No attendance recorded for this period." as NSString).draw(
                at: CGPoint(x: margin + 6, y: y + 4),
                withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
            )
            y += 24
            return y
        }

        var isEven = false
        for entry in entries {
            checkNewPage(18)

            let entryStudent = state.students.first { $0.id == entry.studentID }
            let studentName = entryStudent?.name ?? "Student"

            if isEven {
                let bgRect = CGRect(x: margin, y: y, width: contentWidth, height: 16)
                UIColor.systemGray6.setFill()
                UIRectFill(bgRect)
            }

            (entry.day as NSString).draw(at: CGPoint(x: margin + 6, y: y + 3), withAttributes: rowAttr)
            (studentName as NSString).draw(at: CGPoint(x: margin + 110, y: y + 3), withAttributes: rowAttr)
            ("\(entry.minutes) min" as NSString).draw(at: CGPoint(x: margin + 300, y: y + 3), withAttributes: rowAttr)
            (String(format: "%.2f hrs", Double(entry.minutes) / 60.0) as NSString).draw(at: CGPoint(x: margin + 420, y: y + 3), withAttributes: rowAttr)

            y += 16
            isEven.toggle()
        }

        y += 12
        return y
    }

    private static func drawActivitiesSection(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        checkNewPage(40)

        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        ("Learning Activities & Extracurriculars" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.label]
        )
        y += 18

        let thFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let thAttr: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: UIColor.secondaryLabel]
        ("Date" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
        ("Activity Title" as NSString).draw(at: CGPoint(x: margin + 110, y: y), withAttributes: thAttr)
        ("Student" as NSString).draw(at: CGPoint(x: margin + 330, y: y), withAttributes: thAttr)
        ("Duration" as NSString).draw(at: CGPoint(x: margin + 450, y: y), withAttributes: thAttr)
        y += 14

        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        line.lineWidth = 0.5
        UIColor.separator.setStroke()
        line.stroke()
        y += 4

        let activities = state.activities(for: student?.id, in: year).sorted { $0.day < $1.day }
        let rowFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let rowAttr: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.label]

        if activities.isEmpty {
            ("No independent activities logged for this period." as NSString).draw(
                at: CGPoint(x: margin + 6, y: y + 4),
                withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
            )
            y += 24
            return y
        }

        var isEven = false
        for act in activities {
            checkNewPage(18)
            let st = state.students.first { $0.id == act.studentID }
            let studentName = st?.name ?? "Student"

            if isEven {
                let bgRect = CGRect(x: margin, y: y, width: contentWidth, height: 16)
                UIColor.systemGray6.setFill()
                UIRectFill(bgRect)
            }

            (act.day as NSString).draw(at: CGPoint(x: margin + 6, y: y + 3), withAttributes: rowAttr)
            (act.title as NSString).draw(at: CGPoint(x: margin + 110, y: y + 3), withAttributes: rowAttr)
            (studentName as NSString).draw(at: CGPoint(x: margin + 330, y: y + 3), withAttributes: rowAttr)
            ("\(act.minutes) min" as NSString).draw(at: CGPoint(x: margin + 450, y: y + 3), withAttributes: rowAttr)

            y += 16
            isEven.toggle()
        }

        y += 12
        return y
    }

    private static func drawCurriculumSection(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        checkNewPage(40)

        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        ("Curriculum & Course Progress" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.label]
        )
        y += 18

        let targetStudents = student != nil ? [student!] : state.students
        let rowFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let rowAttr: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.label]
        let thFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let thAttr: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: UIColor.secondaryLabel]

        for st in targetStudents {
            let studentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentLessonIDs.contains($0.id) }.map(\.courseID))
            let courses = state.courses.filter { studentCourseIDs.contains($0.id) }
            for course in courses {
                checkNewPage(50)

                let courseHeader = "\(course.title) — \(st.name)"
                (courseHeader as NSString).draw(
                    at: CGPoint(x: margin + 4, y: y),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: UIColor.label]
                )
                y += 14

                // Table Header
                ("#" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
                ("Lesson Title" as NSString).draw(at: CGPoint(x: margin + 35, y: y), withAttributes: thAttr)
                ("Status" as NSString).draw(at: CGPoint(x: margin + 320, y: y), withAttributes: thAttr)
                ("Completed Date" as NSString).draw(at: CGPoint(x: margin + 430, y: y), withAttributes: thAttr)
                y += 12

                let lessons = state.lessons.filter { $0.courseID == course.id }.sorted { $0.sequence < $1.sequence }
                let assignments = state.assignments.filter { $0.studentID == st.id }

                var isEven = false
                for lesson in lessons {
                    checkNewPage(16)
                    let assign = assignments.first { $0.lessonID == lesson.id }
                    let status = assign?.status.rawValue.capitalized ?? "Planned"
                    let completed = assign?.completedDay ?? "—"

                    if isEven {
                        let bgRect = CGRect(x: margin, y: y, width: contentWidth, height: 15)
                        UIColor.systemGray6.setFill()
                        UIRectFill(bgRect)
                    }

                    ("\(lesson.sequence)" as NSString).draw(at: CGPoint(x: margin + 6, y: y + 2), withAttributes: rowAttr)
                    (lesson.title as NSString).draw(at: CGPoint(x: margin + 35, y: y + 2), withAttributes: rowAttr)
                    (status as NSString).draw(at: CGPoint(x: margin + 320, y: y + 2), withAttributes: rowAttr)
                    (completed as NSString).draw(at: CGPoint(x: margin + 430, y: y + 2), withAttributes: rowAttr)

                    y += 15
                    isEven.toggle()
                }
                y += 10
            }
        }

        return y
    }

    private static func drawReadingLogSection(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        checkNewPage(40)

        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        ("OFFICIAL READING LOG & BOOK LIST" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.label]
        )
        y += 18

        let rowFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let rowAttr: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.label]
        let thFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let thAttr: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: UIColor.secondaryLabel]

        // Table Header
        ("Book Title & Author" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
        ("Format" as NSString).draw(at: CGPoint(x: margin + 220, y: y), withAttributes: thAttr)
        ("Status" as NSString).draw(at: CGPoint(x: margin + 295, y: y), withAttributes: thAttr)
        ("Progress" as NSString).draw(at: CGPoint(x: margin + 375, y: y), withAttributes: thAttr)
        ("Rating" as NSString).draw(at: CGPoint(x: margin + 440, y: y), withAttributes: thAttr)
        ("Completed" as NSString).draw(at: CGPoint(x: margin + 490, y: y), withAttributes: thAttr)
        y += 12

        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        line.lineWidth = 0.5
        UIColor.separator.setStroke()
        line.stroke()
        y += 4

        let books = state.books(for: student?.id, in: year)
        if books.isEmpty {
            ("No books logged for this period." as NSString).draw(
                at: CGPoint(x: margin + 6, y: y + 2),
                withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
            )
            y += 18
        } else {
            var isEven = false
            for book in books {
                checkNewPage(16)
                if isEven {
                    let rowBg = CGRect(x: margin, y: y - 2, width: contentWidth, height: 14)
                    UIColor.systemGray6.withAlphaComponent(0.5).setFill()
                    UIRectFill(rowBg)
                }

                let titleAuthor = "\(book.title) — \(book.author)"
                (titleAuthor as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: rowAttr)
                (book.format.rawValue as NSString).draw(at: CGPoint(x: margin + 220, y: y), withAttributes: rowAttr)
                (book.status.rawValue as NSString).draw(at: CGPoint(x: margin + 295, y: y), withAttributes: rowAttr)

                let progressStr: String
                if let cur = book.currentPage, let tot = book.totalPages {
                    progressStr = "p. \(cur)/\(tot)"
                } else if let cur = book.currentPage {
                    progressStr = "p. \(cur)"
                } else {
                    progressStr = "—"
                }
                (progressStr as NSString).draw(at: CGPoint(x: margin + 375, y: y), withAttributes: rowAttr)

                let ratingStr = book.rating != nil ? "\(book.rating!)★" : "—"
                (ratingStr as NSString).draw(at: CGPoint(x: margin + 440, y: y), withAttributes: rowAttr)
                ((book.completedDay ?? "—") as NSString).draw(at: CGPoint(x: margin + 490, y: y), withAttributes: rowAttr)

                y += 14
                isEven.toggle()
            }
        }

        y += 14

        let logs = state.readingLogs(for: student?.id, in: year)
        if !logs.isEmpty {
            checkNewPage(35)
            ("RECENT READING SESSIONS" as NSString).draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: UIColor.label]
            )
            y += 14

            ("Date" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
            ("Book" as NSString).draw(at: CGPoint(x: margin + 100, y: y), withAttributes: thAttr)
            ("Duration" as NSString).draw(at: CGPoint(x: margin + 320, y: y), withAttributes: thAttr)
            ("Pages Read" as NSString).draw(at: CGPoint(x: margin + 400, y: y), withAttributes: thAttr)
            y += 12

            let logLine = UIBezierPath()
            logLine.move(to: CGPoint(x: margin, y: y))
            logLine.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            logLine.lineWidth = 0.5
            UIColor.separator.setStroke()
            logLine.stroke()
            y += 4

            var isLogEven = false
            for log in logs.prefix(30) {
                checkNewPage(16)
                if isLogEven {
                    let rowBg = CGRect(x: margin, y: y - 2, width: contentWidth, height: 14)
                    UIColor.systemGray6.withAlphaComponent(0.5).setFill()
                    UIRectFill(rowBg)
                }

                let bookTitle = state.books.first(where: { $0.id == log.bookID })?.title ?? "Unknown"
                (log.day as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: rowAttr)
                (bookTitle as NSString).draw(at: CGPoint(x: margin + 100, y: y), withAttributes: rowAttr)
                ("\(log.minutes) min" as NSString).draw(at: CGPoint(x: margin + 320, y: y), withAttributes: rowAttr)
                ((log.pagesRead != nil ? "\(log.pagesRead!) pages" : "—") as NSString).draw(at: CGPoint(x: margin + 400, y: y), withAttributes: rowAttr)

                y += 14
                isLogEven.toggle()
            }
        }

        y += 12
        return y
    }

    private static func drawSignatureBlock(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void
    ) -> CGFloat {
        var y = currentY
        checkNewPage(90)

        y += 10
        let attestationFont = UIFont.italicSystemFont(ofSize: 8)
        let attestationText = "Legal Attestation: I, the undersigned parent / legal guardian, hereby attest and affirm under penalty of perjury that the attendance, instructional hours, and educational coursework recorded above represent bona fide home education conducted in compliance with applicable state home education laws and statutory requirements."
        let attestationRect = CGRect(x: margin, y: y, width: contentWidth, height: 30)
        (attestationText as NSString).draw(in: attestationRect, withAttributes: [.font: attestationFont, .foregroundColor: UIColor.secondaryLabel])
        y += 36

        // Signature Line
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: UIColor.label]

        // Parent Signature Line
        let line1 = UIBezierPath()
        line1.move(to: CGPoint(x: margin, y: y + 16))
        line1.addLine(to: CGPoint(x: margin + 260, y: y + 16))
        line1.lineWidth = 0.5
        UIColor.label.setStroke()
        line1.stroke()
        ("Parent / Guardian Signature" as NSString).draw(at: CGPoint(x: margin, y: y + 20), withAttributes: labelAttr)

        // Date Line
        let line2 = UIBezierPath()
        line2.move(to: CGPoint(x: margin + 300, y: y + 16))
        line2.addLine(to: CGPoint(x: margin + 440, y: y + 16))
        line2.lineWidth = 0.5
        UIColor.label.setStroke()
        line2.stroke()
        ("Date Signed" as NSString).draw(at: CGPoint(x: margin + 300, y: y + 20), withAttributes: labelAttr)

        y += 40
        return y
    }

    private static func drawTranscriptSection(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        checkNewPage(40)

        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        ("Academic Coursework & Grades" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.label]
        )
        y += 18

        let targetStudents = student != nil ? [student!] : state.students
        let rowFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let rowAttr: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.label]
        let thFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let thAttr: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: UIColor.secondaryLabel]

        for st in targetStudents {
            checkNewPage(45)

            let header = "Student: \(st.name) • Grade Level: \(st.gradeLevel)"
            (header as NSString).draw(
                at: CGPoint(x: margin + 4, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: UIColor.label]
            )
            y += 14

            // Table Header
            ("Course Title" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
            ("Weight" as NSString).draw(at: CGPoint(x: margin + 200, y: y), withAttributes: thAttr)
            ("Credits Att." as NSString).draw(at: CGPoint(x: margin + 270, y: y), withAttributes: thAttr)
            ("Credits Earn." as NSString).draw(at: CGPoint(x: margin + 345, y: y), withAttributes: thAttr)
            ("Average %" as NSString).draw(at: CGPoint(x: margin + 420, y: y), withAttributes: thAttr)
            ("Letter" as NSString).draw(at: CGPoint(x: margin + 485, y: y), withAttributes: thAttr)
            y += 12

            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: y))
            line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            line.lineWidth = 0.5
            UIColor.separator.setStroke()
            line.stroke()
            y += 4

            let studentAssignmentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentAssignmentLessonIDs.contains($0.id) }.map(\.courseID))
            let courses = state.courses.filter { studentCourseIDs.contains($0.id) }

            if courses.isEmpty {
                ("No courses enrolled for this student." as NSString).draw(
                    at: CGPoint(x: margin + 6, y: y + 2),
                    withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
                )
                y += 18
            } else {
                var isEven = false
                var totalAttempted: Double = 0
                var totalEarned: Double = 0

                for course in courses {
                    checkNewPage(16)
                    let creditAttempted = course.creditHours ?? 1.0
                    let creditEarned = state.courseCreditsEarned(for: st.id, courseID: course.id)
                    totalAttempted += creditAttempted
                    totalEarned += creditEarned

                    let grade = state.courseGrade(for: st.id, courseID: course.id)
                    let gradeStr = grade != nil ? String(format: "%.1f%%", grade!) : "In Progress"
                    let letterGrade: String
                    if let grade {
                        switch grade {
                        case 97...: letterGrade = "A+"
                        case 93..<97: letterGrade = "A"
                        case 90..<93: letterGrade = "A-"
                        case 87..<90: letterGrade = "B+"
                        case 83..<87: letterGrade = "B"
                        case 80..<83: letterGrade = "B-"
                        case 77..<80: letterGrade = "C+"
                        case 73..<77: letterGrade = "C"
                        case 70..<73: letterGrade = "C-"
                        case 65..<70: letterGrade = "D"
                        default: letterGrade = "F"
                        }
                    } else {
                        letterGrade = "—"
                    }
                    let weightStr = String(format: "%.1f", course.weight ?? 4.0)

                    if isEven {
                        let bgRect = CGRect(x: margin, y: y, width: contentWidth, height: 15)
                        UIColor.systemGray6.setFill()
                        UIRectFill(bgRect)
                    }

                    (course.title as NSString).draw(at: CGPoint(x: margin + 6, y: y + 2), withAttributes: rowAttr)
                    (weightStr as NSString).draw(at: CGPoint(x: margin + 200, y: y + 2), withAttributes: rowAttr)
                    (String(format: "%.2f", creditAttempted) as NSString).draw(at: CGPoint(x: margin + 270, y: y + 2), withAttributes: rowAttr)
                    (String(format: "%.2f", creditEarned) as NSString).draw(at: CGPoint(x: margin + 345, y: y + 2), withAttributes: rowAttr)
                    (gradeStr as NSString).draw(at: CGPoint(x: margin + 420, y: y + 2), withAttributes: rowAttr)
                    (letterGrade as NSString).draw(at: CGPoint(x: margin + 485, y: y + 2), withAttributes: rowAttr)

                    y += 15
                    isEven.toggle()
                }

                // Summary totals line for this student
                checkNewPage(24)
                y += 4
                let sepLine = UIBezierPath()
                sepLine.move(to: CGPoint(x: margin, y: y))
                sepLine.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                sepLine.lineWidth = 0.5
                UIColor.separator.setStroke()
                sepLine.stroke()
                y += 4

                let unweighted = state.cumulativeGPA(for: st.id, weighted: false)
                let weighted = state.cumulativeGPA(for: st.id, weighted: true)
                let unweightedStr = unweighted != nil ? String(format: "%.2f", unweighted!) : "—"
                let weightedStr = weighted != nil ? String(format: "%.2f", weighted!) : "—"

                let boldFont = UIFont.systemFont(ofSize: 8, weight: .bold)
                let boldAttr: [NSAttributedString.Key: Any] = [.font: boldFont, .foregroundColor: UIColor.label]

                ("TOTALS / GPA" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: boldAttr)
                (String(format: "%.2f", totalAttempted) as NSString).draw(at: CGPoint(x: margin + 270, y: y), withAttributes: boldAttr)
                (String(format: "%.2f", totalEarned) as NSString).draw(at: CGPoint(x: margin + 345, y: y), withAttributes: boldAttr)
                ("GPA: \(unweightedStr) (UW) / \(weightedStr) (W)" as NSString).draw(at: CGPoint(x: margin + 420, y: y), withAttributes: boldAttr)
                y += 18
            }
            y += 10
        }

        return y
    }

    private static func drawReportCardSection(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void,
        state: SchoolState,
        student: Student?,
        year: AcademicYear
    ) -> CGFloat {
        var y = currentY
        checkNewPage(40)

        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        ("Official Academic Report Card" as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.label]
        )
        y += 18

        let targetStudents = student != nil ? [student!] : state.students
        let rowFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let rowAttr: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.label]
        let subRowFont = UIFont.systemFont(ofSize: 7, weight: .regular)
        let subRowAttr: [NSAttributedString.Key: Any] = [.font: subRowFont, .foregroundColor: UIColor.secondaryLabel]
        let thFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let thAttr: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: UIColor.secondaryLabel]

        for st in targetStudents {
            checkNewPage(50)

            let header = "Student: \(st.name) • Grade Level: \(st.gradeLevel)"
            (header as NSString).draw(
                at: CGPoint(x: margin + 4, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: UIColor.label]
            )
            y += 14

            // Table Header
            ("Subject / Course" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: thAttr)
            ("Credit" as NSString).draw(at: CGPoint(x: margin + 260, y: y), withAttributes: thAttr)
            ("Weight" as NSString).draw(at: CGPoint(x: margin + 310, y: y), withAttributes: thAttr)
            ("Final Score %" as NSString).draw(at: CGPoint(x: margin + 370, y: y), withAttributes: thAttr)
            ("Letter Grade" as NSString).draw(at: CGPoint(x: margin + 450, y: y), withAttributes: thAttr)
            ("Status" as NSString).draw(at: CGPoint(x: margin + 510, y: y), withAttributes: thAttr)
            y += 12

            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: y))
            line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            line.lineWidth = 0.5
            UIColor.separator.setStroke()
            line.stroke()
            y += 4

            let studentAssignmentLessonIDs = Set(state.assignments.filter { $0.studentID == st.id }.map(\.lessonID))
            let studentCourseIDs = Set(state.lessons.filter { studentAssignmentLessonIDs.contains($0.id) }.map(\.courseID))
            let courses = state.courses.filter { studentCourseIDs.contains($0.id) }

            if courses.isEmpty {
                ("No courses enrolled for this student." as NSString).draw(
                    at: CGPoint(x: margin + 6, y: y + 2),
                    withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
                )
                y += 18
            } else {
                var isEven = false
                var totalAttempted: Double = 0
                var totalEarned: Double = 0

                for course in courses {
                    let categories = state.gradeCategories.filter { $0.courseID == course.id }
                    let extraHeight: CGFloat = categories.isEmpty ? 0 : CGFloat(categories.count * 12 + 2)
                    checkNewPage(18 + extraHeight)

                    let creditAttempted = course.creditHours ?? 1.0
                    let creditEarned = state.courseCreditsEarned(for: st.id, courseID: course.id)
                    totalAttempted += creditAttempted
                    totalEarned += creditEarned

                    let grade = state.courseGrade(for: st.id, courseID: course.id)
                    let gradeStr = grade != nil ? String(format: "%.1f%%", grade!) : "In Progress"
                    let letterGrade: String
                    if let grade {
                        switch grade {
                        case 97...: letterGrade = "A+"
                        case 93..<97: letterGrade = "A"
                        case 90..<93: letterGrade = "A-"
                        case 87..<90: letterGrade = "B+"
                        case 83..<87: letterGrade = "B"
                        case 80..<83: letterGrade = "B-"
                        case 77..<80: letterGrade = "C+"
                        case 73..<77: letterGrade = "C"
                        case 70..<73: letterGrade = "C-"
                        case 65..<70: letterGrade = "D"
                        default: letterGrade = "F"
                        }
                    } else {
                        letterGrade = "—"
                    }
                    let statusStr = grade != nil ? ((grade! >= 65.0 ? "Passed" : "Not Passed") as NSString) : ("Enrolled" as NSString)
                    let rowHeight: CGFloat = 16 + extraHeight

                    if isEven {
                        let bgRect = CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)
                        UIColor.systemGray6.setFill()
                        UIRectFill(bgRect)
                    }

                    (course.title as NSString).draw(at: CGPoint(x: margin + 6, y: y + 2), withAttributes: rowAttr)
                    (String(format: "%.1f cr", creditAttempted) as NSString).draw(at: CGPoint(x: margin + 260, y: y + 2), withAttributes: rowAttr)
                    (String(format: "%.1f", course.weight ?? 4.0) as NSString).draw(at: CGPoint(x: margin + 310, y: y + 2), withAttributes: rowAttr)
                    (gradeStr as NSString).draw(at: CGPoint(x: margin + 370, y: y + 2), withAttributes: rowAttr)
                    (letterGrade as NSString).draw(at: CGPoint(x: margin + 450, y: y + 2), withAttributes: rowAttr)
                    statusStr.draw(at: CGPoint(x: margin + 510, y: y + 2), withAttributes: rowAttr)

                    var subY = y + 16
                    for cat in categories {
                        let catAvg = state.categoryGrade(for: st.id, categoryID: cat.id)
                        let catAvgStr = catAvg != nil ? String(format: "%.0f%%", catAvg!) : "No work logged"
                        let catLine = "• \(cat.name) (\(Int(cat.weight * 100))% weight): \(catAvgStr)"
                        (catLine as NSString).draw(at: CGPoint(x: margin + 18, y: subY), withAttributes: subRowAttr)
                        subY += 12
                    }

                    y += rowHeight
                    isEven.toggle()
                }

                // Summary totals line for this student
                checkNewPage(24)
                y += 4
                let sepLine = UIBezierPath()
                sepLine.move(to: CGPoint(x: margin, y: y))
                sepLine.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                sepLine.lineWidth = 0.5
                UIColor.separator.setStroke()
                sepLine.stroke()
                y += 4

                let unweighted = state.cumulativeGPA(for: st.id, weighted: false)
                let weighted = state.cumulativeGPA(for: st.id, weighted: true)
                let unweightedStr = unweighted != nil ? String(format: "%.2f", unweighted!) : "—"
                let weightedStr = weighted != nil ? String(format: "%.2f", weighted!) : "—"

                let boldFont = UIFont.systemFont(ofSize: 8, weight: .bold)
                let boldAttr: [NSAttributedString.Key: Any] = [.font: boldFont, .foregroundColor: UIColor.label]

                ("ACADEMIC TOTALS" as NSString).draw(at: CGPoint(x: margin + 6, y: y), withAttributes: boldAttr)
                (String(format: "Attempted: %.1f", totalAttempted) as NSString).draw(at: CGPoint(x: margin + 200, y: y), withAttributes: boldAttr)
                (String(format: "Earned: %.1f", totalEarned) as NSString).draw(at: CGPoint(x: margin + 300, y: y), withAttributes: boldAttr)
                ("GPA: \(unweightedStr) (Unweighted) / \(weightedStr) (Weighted)" as NSString).draw(at: CGPoint(x: margin + 380, y: y), withAttributes: boldAttr)
                y += 20
            }
            y += 10
        }

        return y
    }

    private static func drawTranscriptSignatureBlock(
        in context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        checkNewPage: (CGFloat) -> Void
    ) -> CGFloat {
        var y = currentY
        checkNewPage(90)

        y += 10
        let attestationFont = UIFont.italicSystemFont(ofSize: 8)
        let attestationText = "Official Transcript Attestation: I, the undersigned primary educator and administrator of this home education program, hereby certify and affirm that this transcript is an accurate, official, and complete academic record of the coursework, grades, and credits earned by the student in compliance with state homeschooling provisions."
        let attestationRect = CGRect(x: margin, y: y, width: contentWidth, height: 30)
        (attestationText as NSString).draw(in: attestationRect, withAttributes: [.font: attestationFont, .foregroundColor: UIColor.secondaryLabel])
        y += 36

        // Signature Line
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: UIColor.label]

        // Administrator Signature Line
        let line1 = UIBezierPath()
        line1.move(to: CGPoint(x: margin, y: y + 16))
        line1.addLine(to: CGPoint(x: margin + 260, y: y + 16))
        line1.lineWidth = 0.5
        UIColor.label.setStroke()
        line1.stroke()
        ("Home School Administrator / Parent Signature" as NSString).draw(at: CGPoint(x: margin, y: y + 20), withAttributes: labelAttr)

        // Date Line
        let line2 = UIBezierPath()
        line2.move(to: CGPoint(x: pageWidth - margin - 150, y: y + 16))
        line2.addLine(to: CGPoint(x: pageWidth - margin, y: y + 16))
        line2.lineWidth = 0.5
        UIColor.label.setStroke()
        line2.stroke()
        ("Date" as NSString).draw(at: CGPoint(x: pageWidth - margin - 150, y: y + 20), withAttributes: labelAttr)

        y += 40
        return y
    }
}
#endif

// MARK: - PDFKit SwiftUI View Wrapper

#if canImport(PDFKit)
public struct PDFKitView: UIViewRepresentable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    public func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.dataRepresentation() != data {
            uiView.document = PDFDocument(data: data)
        }
    }
}
#endif
