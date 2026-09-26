import Foundation

public enum SampleDataGenerator {
    public static func generateSampleState() -> SchoolState {
        var state = SchoolState()
        state.selectedStateCode = "FL"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current
        let todayString = dateFormatter.string(from: Date())

        // 1. Academic Year & Terms
        let yearID = UUID()
        let term1ID = UUID()
        let term2ID = UUID()

        let academicYear = AcademicYear(
            id: yearID,
            title: "2026–2027 School Year",
            startDay: "2026-08-15",
            endDay: "2027-06-01"
        )
        let term1 = AcademicTerm(
            id: term1ID,
            academicYearID: yearID,
            title: "Fall Semester",
            startDay: "2026-08-15",
            endDay: "2026-12-20"
        )
        let term2 = AcademicTerm(
            id: term2ID,
            academicYearID: yearID,
            title: "Spring Semester",
            startDay: "2027-01-05",
            endDay: "2027-06-01"
        )

        state.academicYears = [academicYear]
        state.terms = [term1, term2]
        state.activeYearID = yearID

        // 2. Students
        let emmaID = UUID()
        let emma = Student(id: emmaID, name: "Emma", gradeLevel: "4th Grade")

        let lucasID = UUID()
        let lucas = Student(id: lucasID, name: "Lucas", gradeLevel: "1st Grade")

        state.students = [emma, lucas]

        // 3. Courses & Lessons
        // Math (Emma)
        let mathCourseID = UUID()
        let mathCourse = Course(id: mathCourseID, title: "Singapore Math 4A", creditHours: 1.0, weight: 1.0)
        state.courses.append(mathCourse)

        let mathCategoryHomework = GradeCategory(id: UUID(), courseID: mathCourseID, name: "Homework", weight: 0.30)
        let mathCategoryQuizzes = GradeCategory(id: UUID(), courseID: mathCourseID, name: "Quizzes", weight: 0.30)
        let mathCategoryTests = GradeCategory(id: UUID(), courseID: mathCourseID, name: "Unit Exams", weight: 0.40)
        state.gradeCategories.append(contentsOf: [mathCategoryHomework, mathCategoryQuizzes, mathCategoryTests])

        let mathLessonTitles = [
            "Multi-Digit Multiplication Strategies",
            "Long Division by Single Digits",
            "Prime & Composite Numbers",
            "Fraction Foundations & Common Denominators",
            "Adding Unlike Fractions",
            "Area & Perimeter of Complex Shapes",
            "Mid-Unit Review & Quiz",
            "Decimals Introduction: Tenths & Hundredths"
        ]

        var mathLessons: [Lesson] = []
        var mathAssignments: [Assignment] = []
        for (i, title) in mathLessonTitles.enumerated() {
            let lessonID = UUID()
            let lesson = Lesson(id: lessonID, courseID: mathCourseID, title: title, sequence: i + 1)
            mathLessons.append(lesson)

            let isCompleted = i < 4
            let isToday = i == 4
            let scheduledDay = isCompleted ? "2026-09-\(String(format: "%02d", 15 + i))" : (isToday ? todayString : nil)

            let assignment = Assignment(
                id: UUID(),
                studentID: emmaID,
                lessonID: lessonID,
                scheduledDay: scheduledDay,
                status: isCompleted ? .completed : (isToday ? .inProgress : .planned),
                completedDay: isCompleted ? scheduledDay : nil,
                grade: isCompleted ? [95.0, 92.0, 100.0, 88.0][i] : nil,
                notes: isCompleted ? "Mastered concepts with minimal guidance." : nil,
                categoryID: isCompleted ? (i == 2 ? mathCategoryQuizzes.id : mathCategoryHomework.id) : nil
            )
            mathAssignments.append(assignment)
        }
        state.lessons.append(contentsOf: mathLessons)
        state.assignments.append(contentsOf: mathAssignments)

        // Science (Emma)
        let scienceCourseID = UUID()
        let scienceCourse = Course(id: scienceCourseID, title: "Earth & Space Science", creditHours: 1.0, weight: 1.0)
        state.courses.append(scienceCourse)

        let scienceLessonTitles = [
            "Layers of the Earth & Tectonic Plates",
            "Rock Cycle: Igneous, Sedimentary, Metamorphic",
            "Atmosphere & Weather Patterns",
            "Solar System: Terrestrial Planets",
            "Solar System: Gas Giants & Moons"
        ]

        for (i, title) in scienceLessonTitles.enumerated() {
            let lessonID = UUID()
            let lesson = Lesson(id: lessonID, courseID: scienceCourseID, title: title, sequence: i + 1)
            state.lessons.append(lesson)

            let isCompleted = i < 2
            let isToday = i == 2
            let scheduledDay = isCompleted ? "2026-09-\(String(format: "%02d", 16 + i))" : (isToday ? todayString : nil)

            let assignment = Assignment(
                id: UUID(),
                studentID: emmaID,
                lessonID: lessonID,
                scheduledDay: scheduledDay,
                status: isCompleted ? .completed : (isToday ? .planned : .planned),
                completedDay: isCompleted ? scheduledDay : nil,
                grade: isCompleted ? 96.0 : nil,
                notes: isCompleted ? "Completed laboratory sketching." : nil
            )
            state.assignments.append(assignment)
        }

        // Reading & Phonics (Lucas)
        let phonicsCourseID = UUID()
        let phonicsCourse = Course(id: phonicsCourseID, title: "1st Grade Phonics & Reading", creditHours: 1.0, weight: 1.0)
        state.courses.append(phonicsCourse)

        let phonicsLessonTitles = [
            "Short Vowel Word Families (-at, -an, -ap)",
            "Consonant Blends (bl, cl, fl, gl)",
            "Sight Words: List A Review",
            "Silent 'e' Long Vowels",
            "Reading Aloud: Simple Sentence Fluency"
        ]

        for (i, title) in phonicsLessonTitles.enumerated() {
            let lessonID = UUID()
            let lesson = Lesson(id: lessonID, courseID: phonicsCourseID, title: title, sequence: i + 1)
            state.lessons.append(lesson)

            let isCompleted = i < 3
            let isToday = i == 3
            let scheduledDay = isCompleted ? "2026-09-\(String(format: "%02d", 15 + i))" : (isToday ? todayString : nil)

            let assignment = Assignment(
                id: UUID(),
                studentID: lucasID,
                lessonID: lessonID,
                scheduledDay: scheduledDay,
                status: isCompleted ? .completed : (isToday ? .planned : .planned),
                completedDay: isCompleted ? scheduledDay : nil,
                grade: isCompleted ? 100.0 : nil,
                notes: isCompleted ? "Read aloud enthusiastically!" : nil
            )
            state.assignments.append(assignment)
        }

        // 4. Books & Reading Logs
        let book1ID = UUID()
        let book1 = BookEntry(
            id: book1ID,
            studentID: emmaID,
            title: "The Lion, the Witch and the Wardrobe",
            author: "C.S. Lewis",
            genre: "Fantasy Classic",
            isbn: "9780064404990",
            format: .physical,
            status: .completed,
            totalPages: 208,
            currentPage: 208,
            rating: 5,
            notes: "Loved Aslan and the story of Narnia.",
            startDay: "2026-09-01",
            completedDay: "2026-09-18",
            academicYearID: yearID
        )

        let book2ID = UUID()
        let book2 = BookEntry(
            id: book2ID,
            studentID: emmaID,
            title: "Charlotte's Web",
            author: "E.B. White",
            genre: "Children's Literature",
            isbn: "9780061124952",
            format: .physical,
            status: .reading,
            totalPages: 184,
            currentPage: 112,
            rating: 5,
            notes: "Reading chapter 14.",
            startDay: "2026-09-19",
            academicYearID: yearID
        )

        let book3ID = UUID()
        let book3 = BookEntry(
            id: book3ID,
            studentID: lucasID,
            title: "Frog and Toad Are Friends",
            author: "Arnold Lobel",
            genre: "Early Reader",
            isbn: "9780064440202",
            format: .physical,
            status: .completed,
            totalPages: 64,
            currentPage: 64,
            rating: 5,
            notes: "Lucas laughed out loud at the bathing suit chapter.",
            startDay: "2026-09-10",
            completedDay: "2026-09-16",
            academicYearID: yearID
        )

        state.books = [book1, book2, book3]

        state.readingLogs = [
            ReadingLogEntry(
                id: UUID(),
                bookID: book1ID,
                studentID: emmaID,
                day: "2026-09-15",
                minutes: 30,
                pagesRead: 25,
                notes: "Chapters 8–9."
            ),
            ReadingLogEntry(
                id: UUID(),
                bookID: book2ID,
                studentID: emmaID,
                day: "2026-09-20",
                minutes: 25,
                pagesRead: 20,
                notes: "Chapters 12–13."
            ),
            ReadingLogEntry(
                id: UUID(),
                bookID: book3ID,
                studentID: lucasID,
                day: "2026-09-15",
                minutes: 20,
                pagesRead: 16,
                notes: "Read with Mom."
            )
        ]

        // 5. Attendance (10 days recorded for both students)
        let attendanceDates = [
            "2026-09-08", "2026-09-09", "2026-09-10", "2026-09-11", "2026-09-12",
            "2026-09-15", "2026-09-16", "2026-09-17", "2026-09-18", "2026-09-19"
        ]

        for date in attendanceDates {
            state.attendance.append(AttendanceEntry(
                id: UUID(),
                studentID: emmaID,
                day: date,
                minutes: 240
            ))
            state.attendance.append(AttendanceEntry(
                id: UUID(),
                studentID: lucasID,
                day: date,
                minutes: 180
            ))
        }

        // 6. Portfolio Items
        state.portfolioItems = [
            PortfolioItem(
                id: UUID(),
                studentID: emmaID,
                title: "Solar System Watercolor Chart",
                day: "2026-09-17",
                courseID: scienceCourseID,
                imageFileName: "sample_solar_chart.jpg",
                notes: "Hand-painted scale visualization of inner and outer planetary orbits."
            ),
            PortfolioItem(
                id: UUID(),
                studentID: lucasID,
                title: "Handwriting & Phonics Mini-Book",
                day: "2026-09-18",
                courseID: phonicsCourseID,
                imageFileName: "sample_phonics_booklet.jpg",
                notes: "Short vowel story booklet written and colored independently."
            )
        ]

        return state
    }
}
