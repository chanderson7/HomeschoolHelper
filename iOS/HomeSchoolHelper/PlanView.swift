import SwiftUI
import HomeschoolCore

struct PlanView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var studentID: UUID?
    @State private var showBuilder = false
    @State private var editingCourse: Course?
    @State private var courseToDelete: Course?

    private var studentCourses: [Course] {
        if let studentID {
            let courseIDs = Set(store.state.assignments.filter { $0.studentID == studentID }.compactMap { store.lesson(for: $0.lessonID)?.courseID })
            return store.state.courses.filter { courseIDs.contains($0.id) }
        } else {
            return store.state.courses
        }
    }

    private var todayAssignments: [Assignment] {
        store.state.assignments.filter {
            $0.scheduledDay == SchoolDate.today && (studentID == nil || $0.studentID == studentID)
        }
    }

    private var flexibleAssignments: [Assignment] {
        store.state.assignments.filter {
            $0.scheduledDay == nil && (studentID == nil || $0.studentID == studentID)
        }
    }

    @State private var selectedCourseForRoadmap: Course?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StudentScopePicker(students: store.state.students, selection: $studentID)
                        .listRowInsets(EdgeInsets())
                }

                if store.state.students.isEmpty {
                    emptyLearnersSection
                } else if store.state.courses.isEmpty {
                    emptyCoursesSection
                } else {
                    coursesSection
                    todayReferenceSection
                    flexibleReferenceSection
                }
            }
            .navigationTitle("Curriculum & Plan")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Subject", systemImage: "plus") { showBuilder = true }
                        .accessibilityIdentifier("addCourse")
                }
                SaveStatusToolbar()
            }
            .sheet(isPresented: $showBuilder) { SequenceBuilderView() }
            .sheet(item: $selectedCourseForRoadmap) { course in
                CourseRoadmapDetailView(course: course, studentID: studentID)
            }
            .sheet(item: $editingCourse) { course in
                EditCourseView(course: course)
            }
            .confirmationDialog(
                "Delete Subject?",
                isPresented: Binding(
                    get: { courseToDelete != nil },
                    set: { if !$0 { courseToDelete = nil } }
                ),
                presenting: courseToDelete
            ) { course in
                Button("Delete \(course.title)", role: .destructive) {
                    _ = store.deleteCourse(id: course.id)
                }
                .accessibilityIdentifier("confirmDeleteCourse")
                Button("Cancel", role: .cancel) {
                    courseToDelete = nil
                }
            } message: { course in
                Text("Deleting \(course.title) will permanently remove this course, all of its lessons, and all associated student assignments.")
            }
        }
    }

    @ViewBuilder
    private var emptyLearnersSection: some View {
        Section {
            ContentUnavailableView("No learners in household", systemImage: "person.2.slash", description: Text("Add a learner in the Family tab first."))
        }
    }

    @ViewBuilder
    private var emptyCoursesSection: some View {
        Section {
            VStack(alignment: .center, spacing: 14) {
                Image(systemName: "book.closed")
                    .font(.system(size: 40))
                    .foregroundStyle(Sage.accent)
                    .padding(.top, 12)
                Text("No subjects created yet")
                    .font(.headline)
                Text("Create courses like Math, Reading, or Science to generate lesson sequences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showBuilder = true
                } label: {
                    Label("Add First Subject", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Sage.accent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var coursesSection: some View {
        Section("Subjects & Curricula") {
            ForEach(studentCourses) { course in
                CourseRowView(course: course, studentID: studentID) {
                    selectedCourseForRoadmap = course
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        courseToDelete = course
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteCourse-\(course.title)")

                    Button {
                        editingCourse = course
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Sage.accent)
                    .accessibilityIdentifier("editCourse-\(course.title)")
                }
                .contextMenu {
                    Button {
                        editingCourse = course
                    } label: {
                        Label("Edit Subject Title", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        courseToDelete = course
                    } label: {
                        Label("Delete Subject", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var todayReferenceSection: some View {
        Section("Today's Lessons for Quick Reference") {
            if todayAssignments.isEmpty {
                Text("No dated lessons scheduled for today.").foregroundStyle(.secondary)
            } else {
                ForEach(todayAssignments) { assignment in
                    AssignmentCard(assignment: assignment)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
    }

    @ViewBuilder
    private var flexibleReferenceSection: some View {
        Section("Flexible work") {
            if flexibleAssignments.isEmpty {
                Text("No flexible lessons.").foregroundStyle(.secondary)
            } else {
                ForEach(flexibleAssignments) { assignment in
                    AssignmentCard(assignment: assignment)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
    }
}

private struct CourseRowView: View {
    @EnvironmentObject private var store: HomeschoolStore
    let course: Course
    let studentID: UUID?
    var onOpenRoadmap: (() -> Void)? = nil

    private var lessons: [Lesson] {
        store.state.lessons.filter { $0.courseID == course.id }
            .sorted { $0.sequence < $1.sequence }
    }

    private var courseAssignments: [Assignment] {
        store.state.assignments.filter { assignment in
            lessons.map(\.id).contains(assignment.lessonID) && (studentID == nil || assignment.studentID == studentID)
        }
    }

    private var completedCount: Int { courseAssignments.filter { $0.status == .completed }.count }
    private var totalCount: Int { max(lessons.count, courseAssignments.count) }
    private var progress: Double { totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount) }

    private var nextLessonTitle: String? {
        let completedLessonIDs = Set(courseAssignments.filter { $0.status == .completed }.map(\.lessonID))
        return lessons.first { !completedLessonIDs.contains($0.id) }?.title
    }

    private var subjectIcon: String {
        let lower = course.title.lowercased()
        if lower.contains("math") || lower.contains("algebra") || lower.contains("geometry") { return "📐" }
        if lower.contains("read") || lower.contains("lit") || lower.contains("english") { return "📚" }
        if lower.contains("science") || lower.contains("bio") || lower.contains("chem") || lower.contains("physic") { return "🔬" }
        if lower.contains("history") || lower.contains("geography") || lower.contains("social") { return "🧭" }
        if lower.contains("art") || lower.contains("draw") { return "🎨" }
        if lower.contains("music") { return "🎵" }
        if lower.contains("code") || lower.contains("program") { return "💻" }
        return "📖"
    }

    var body: some View {
        Button {
            onOpenRoadmap?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(subjectIcon)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)

                        if let next = nextLessonTitle {
                            Text("Next: \(next)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Sage.accent)
                                .lineLimit(1)
                        } else if totalCount > 0 && completedCount >= totalCount {
                            Text("Curriculum complete 🎉")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Sage.accent)
                        } else {
                            Text("\(lessons.count) lessons total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(completedCount)/\(totalCount) done")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Sage.accent)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }

                ProgressView(value: progress)
                    .tint(Sage.accent)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct CourseRoadmapDetailView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let course: Course
    let studentID: UUID?

    @State private var editingCourse = false
    @State private var showDeleteCourse = false
    @State private var addingLesson = false
    @State private var editingLesson: Lesson?
    @State private var lessonToDelete: Lesson?
    @State private var showingGradeBook = false

    private var currentCourse: Course {
        store.course(for: course.id) ?? course
    }

    private var activeStudent: Student? {
        if let studentID {
            return store.student(for: studentID)
        }
        return store.state.students.first
    }

    private var courseGradeValue: Double? {
        guard let student = activeStudent else { return nil }
        return store.courseGrade(for: student.id, courseID: course.id)
    }

    private var lessons: [Lesson] {
        store.state.lessons.filter { $0.courseID == course.id }
            .sorted { $0.sequence < $1.sequence }
    }

    private var assignments: [Assignment] {
        store.state.assignments.filter { assignment in
            lessons.map(\.id).contains(assignment.lessonID) && (studentID == nil || assignment.studentID == studentID)
        }
    }

    private var completedLessonIDs: Set<UUID> {
        Set(assignments.filter { $0.status == .completed }.map(\.lessonID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRICULUM ROADMAP")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Sage.accent)
                        Text(currentCourse.title)
                            .font(.title.weight(.bold))
                        HStack {
                            Text("\(completedLessonIDs.count) of \(lessons.count) lessons completed")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            if let grade = courseGradeValue {
                                Spacer()
                                Text(String(format: "Grade: %.1f%%", grade))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Sage.accent)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                    VStack(spacing: 0) {
                        ForEach(lessons.indices, id: \.self) { idx in
                            let lesson = lessons[idx]
                            let isDone = completedLessonIDs.contains(lesson.id)
                            let isFirst = (idx == 0)
                            let isLast = (idx == lessons.count - 1)
                            let isNext = !isDone && (idx == 0 || completedLessonIDs.contains(lessons[idx - 1].id))

                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(isFirst ? Color.clear : (isDone ? Sage.accent : Sage.accent.opacity(0.35)))
                                        .frame(width: 3, height: 16)

                                    ZStack {
                                        if isDone {
                                            Circle().fill(Sage.accent).frame(width: 24, height: 24)
                                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                        } else if isNext {
                                            Circle().stroke(Sage.accent, lineWidth: 2.5)
                                                .background(Circle().fill(Sage.accent.opacity(0.15)))
                                                .frame(width: 24, height: 24)
                                            Circle().fill(Sage.accent).frame(width: 10, height: 10)
                                        } else {
                                            Circle().stroke(Sage.accent.opacity(0.4), lineWidth: 2)
                                                .background(Circle().fill(Color(.systemBackground)))
                                                .frame(width: 24, height: 24)
                                        }
                                    }

                                    Rectangle()
                                        .fill(isLast ? Color.clear : Sage.accent.opacity(0.35))
                                        .frame(width: 3)
                                        .frame(maxHeight: .infinity)
                                }
                                .frame(width: 24)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Lesson \(lesson.sequence)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Sage.accent)
                                        Spacer()
                                        if isDone {
                                            Text("Completed ✓")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Sage.accent)
                                        } else if isNext {
                                            Text("Next Milestone")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Color.orange)
                                        }

                                        Menu {
                                            Button {
                                                editingLesson = lesson
                                            } label: {
                                                Label("Edit Title", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                lessonToDelete = lesson
                                            } label: {
                                                Label("Delete Lesson", systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 4)
                                        }
                                        .accessibilityIdentifier("lessonOptions-\(lesson.sequence)")
                                    }

                                    Text(lesson.title)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(isDone ? .secondary : .primary)
                                        .strikethrough(isDone)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isNext ? Sage.accent.opacity(0.6) : Color.secondary.opacity(0.12), lineWidth: isNext ? 1.5 : 1)
                                )
                                .padding(.bottom, 8)
                                .contextMenu {
                                    Button {
                                        editingLesson = lesson
                                    } label: {
                                        Label("Edit Lesson Title", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        lessonToDelete = lesson
                                    } label: {
                                        Label("Delete Lesson", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Sage.background.ignoresSafeArea())
            .navigationTitle("Course Roadmap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingGradeBook = true
                        } label: {
                            Label("Grade Book", systemImage: "chart.bar.doc.horizontal")
                        }
                        .accessibilityIdentifier("roadmapGradeBook")

                        Button {
                            addingLesson = true
                        } label: {
                            Label("Add Lesson", systemImage: "plus")
                        }
                        .accessibilityIdentifier("roadmapAddLesson")

                        Button {
                            editingCourse = true
                        } label: {
                            Label("Edit Subject Title", systemImage: "pencil")
                        }
                        .accessibilityIdentifier("roadmapEditSubject")

                        Divider()

                        Button(role: .destructive) {
                            showDeleteCourse = true
                        } label: {
                            Label("Delete Subject", systemImage: "trash")
                        }
                        .accessibilityIdentifier("roadmapDeleteSubject")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("courseOptionsMenu")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
            .sheet(isPresented: $showingGradeBook) {
                if let student = activeStudent {
                    NavigationStack {
                        GradeBookView(course: currentCourse, student: student)
                            .environmentObject(store)
                    }
                }
            }
            .sheet(isPresented: $addingLesson) {
                AddSingleLessonView(courseID: course.id)
            }
            .sheet(isPresented: $editingCourse) {
                EditCourseView(course: currentCourse)
            }
            .sheet(item: $editingLesson) { lesson in
                EditLessonView(lesson: lesson)
            }
            .confirmationDialog(
                "Delete Lesson?",
                isPresented: Binding(
                    get: { lessonToDelete != nil },
                    set: { if !$0 { lessonToDelete = nil } }
                ),
                presenting: lessonToDelete
            ) { lesson in
                Button("Delete \(lesson.title)", role: .destructive) {
                    _ = store.deleteLesson(id: lesson.id)
                }
                .accessibilityIdentifier("confirmDeleteLesson")
                Button("Cancel", role: .cancel) {
                    lessonToDelete = nil
                }
            } message: { lesson in
                Text("Deleting \"\(lesson.title)\" will permanently remove this lesson and all associated student assignments.")
            }
            .confirmationDialog("Delete Subject?", isPresented: $showDeleteCourse) {
                Button("Delete \(currentCourse.title)", role: .destructive) {
                    _ = store.deleteCourse(id: currentCourse.id)
                    dismiss()
                }
                .accessibilityIdentifier("confirmDeleteCourseInRoadmap")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deleting \(currentCourse.title) will permanently remove this subject, its lessons, and all student assignments.")
            }
        }
    }
}

private struct EditCourseView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let course: Course
    @State private var title: String
    @State private var hasCredits: Bool
    @State private var creditHours: Double
    @State private var weight: Double

    init(course: Course) {
        self.course = course
        _title = State(initialValue: course.title)
        _hasCredits = State(initialValue: course.creditHours != nil)
        _creditHours = State(initialValue: course.creditHours ?? 1.0)
        _weight = State(initialValue: course.weight ?? 4.0)
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Subject Title") {
                    TextField("Course title", text: $title)
                        .accessibilityIdentifier("editCourseTitle")
                }
                Section("High School & Academic Transcript") {
                    Toggle("Award Academic Credits", isOn: $hasCredits)
                        .accessibilityIdentifier("editCourseHasCreditsToggle")
                    if hasCredits {
                        HStack {
                            Text("Credit Hours")
                            Spacer()
                            Picker("Credit Hours", selection: $creditHours) {
                                Text("0.25 Credit (Quarter Year)").tag(0.25)
                                Text("0.50 Credit (One Semester)").tag(0.5)
                                Text("1.00 Credit (Full Year)").tag(1.0)
                                Text("1.50 Credits").tag(1.5)
                                Text("2.00 Credits").tag(2.0)
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("editCourseCreditHoursPicker")
                        }
                        HStack {
                            Text("GPA Weight Scale")
                            Spacer()
                            Picker("GPA Weight Scale", selection: $weight) {
                                Text("Standard (4.0)").tag(4.0)
                                Text("Honors (+0.5 / 4.5)").tag(4.5)
                                Text("AP / College (+1.0 / 5.0)").tag(5.0)
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("editCourseWeightPicker")
                        }
                    }
                }
            }
            .navigationTitle("Edit Subject")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updateCourse(id: course.id, title: title) {
                            let credits = hasCredits ? creditHours : nil
                            let w = hasCredits ? weight : nil
                            if store.updateCourseCredits(id: course.id, creditHours: credits, weight: w) {
                                dismiss()
                            }
                        }
                    }
                    .accessibilityIdentifier("saveEditCourse")
                }
            }
        }
    }
}

private struct EditLessonView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    @State private var title: String

    init(lesson: Lesson) {
        self.lesson = lesson
        _title = State(initialValue: lesson.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Lesson Details") {
                    TextField("Lesson title", text: $title)
                        .accessibilityIdentifier("editLessonTitle")
                }
            }
            .navigationTitle("Edit Lesson")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updateLesson(id: lesson.id, title: title) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveEditLesson")
                }
            }
        }
    }
}

private struct AddSingleLessonView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let courseID: UUID
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("New Lesson") {
                    TextField("Lesson title", text: $title)
                        .accessibilityIdentifier("newLessonTitle")
                }
            }
            .navigationTitle("Add Lesson")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if store.addLesson(to: courseID, title: title) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveNewLesson")
                }
            }
        }
    }
}


struct SequenceBuilderView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var courseTitle = ""
    @State private var selectedStudents = Set<UUID>()
    @State private var lessonText = ""
    @State private var datesLessons = true
    @State private var startDate = Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var hasCredits = false
    @State private var creditHours: Double = 1.0
    @State private var weight: Double = 4.0

    private let weekdayNames = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Course") {
                    TextField("Course title", text: $courseTitle)
                        .accessibilityIdentifier("courseTitle")
                    Text("Use one lesson title per line.").font(.footnote).foregroundStyle(.secondary)
                    TextEditor(text: $lessonText)
                        .frame(minHeight: 130)
                        .accessibilityLabel("Lesson titles")
                        .accessibilityIdentifier("lessonTitles")
                }
                Section("Learners") {
                    if store.state.students.isEmpty {
                        Text("Add a learner on the Family tab first.").foregroundStyle(.secondary)
                    }
                    ForEach(store.state.students) { student in
                        Toggle(student.name, isOn: Binding(
                            get: { selectedStudents.contains(student.id) },
                            set: { enabled in
                                if enabled {
                                    selectedStudents.insert(student.id)
                                } else {
                                    selectedStudents.remove(student.id)
                                }
                            }
                        ))
                        .accessibilityIdentifier("courseStudent-\(student.name)")
                    }
                }
                Section("Schedule") {
                    Toggle("Put lessons on a calendar", isOn: $datesLessons)
                        .accessibilityIdentifier("datedLessonSchedule")
                    if datesLessons {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
                            ForEach(weekdayNames, id: \.0) { weekday in
                                Button(weekday.1) {
                                    if weekdays.contains(weekday.0) { weekdays.remove(weekday.0) } else { weekdays.insert(weekday.0) }
                                }
                                .buttonStyle(.bordered)
                                .tint(weekdays.contains(weekday.0) ? Sage.accent : .gray)
                                .accessibilityLabel("\(weekday.1) school day")
                                .accessibilityValue(weekdays.contains(weekday.0) ? "Selected" : "Not selected")
                            }
                        }
                    } else {
                        Text("Flexible lessons will be available in Plan without a date.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("High School & Academic Transcript (Optional)") {
                    Toggle("Award Academic Credits", isOn: $hasCredits)
                        .accessibilityIdentifier("sequenceHasCreditsToggle")
                    if hasCredits {
                        HStack {
                            Text("Credit Hours")
                            Spacer()
                            Picker("Credit Hours", selection: $creditHours) {
                                Text("0.25 Credit (Quarter Year)").tag(0.25)
                                Text("0.50 Credit (One Semester)").tag(0.5)
                                Text("1.00 Credit (Full Year)").tag(1.0)
                                Text("1.50 Credits").tag(1.5)
                                Text("2.00 Credits").tag(2.0)
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("sequenceCreditHoursPicker")
                        }
                        HStack {
                            Text("GPA Weight Scale")
                            Spacer()
                            Picker("GPA Weight Scale", selection: $weight) {
                                Text("Standard (4.0)").tag(4.0)
                                Text("Honors (+0.5 / 4.5)").tag(4.5)
                                Text("AP / College (+1.0 / 5.0)").tag(5.0)
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("sequenceWeightPicker")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Build Sequence")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let lessons = lessonText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let credits = hasCredits ? creditHours : nil
                        let w = hasCredits ? weight : nil
                        if store.addCourse(
                            title: courseTitle,
                            studentIDs: Array(selectedStudents),
                            lessonTitles: lessons,
                            startDay: datesLessons ? SchoolDate.string(startDate) : nil,
                            weekdays: weekdays,
                            creditHours: credits,
                            weight: w
                        ) {
                            dismiss()
                        }
                    }
                    .disabled(store.state.students.isEmpty)
                    .accessibilityIdentifier("saveCourse")
                }
            }
        }
    }
}

