import SwiftUI
import HomeschoolCore

struct PlanView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var studentID: UUID?
    @State private var showBuilder = false
    @State private var editingCourse: Course?
    @State private var courseToDelete: Course?
    @State private var showRebalanceSheet = false
    @State private var rebalanceTargetCourse: Course?

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
    @State private var animateArt = false
    @State private var sunGlowPulse = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ZStack(alignment: .topTrailing) {
                        // Ambient sun glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.orange.opacity(sunGlowPulse ? 0.22 : 0.08),
                                        Color.yellow.opacity(sunGlowPulse ? 0.12 : 0.03),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 6,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 130, height: 130)
                            .offset(x: 20, y: -25)
                            .scaleEffect(sunGlowPulse ? 1.08 : 0.94)
                            .animation(isRunningUITests ? nil : .easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: sunGlowPulse)
                            .accessibilityHidden(true)

                        // Botanical parchment roadmap & compass art
                        Image("PlanHeroArt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 82)
                            .offset(x: 10, y: -5)
                            .scaleEffect(animateArt ? 1.0 : 0.92)
                            .opacity(animateArt ? 1.0 : 0.0)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "map.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Sage.accent)
                                Text("Curriculum & Roadmap")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Sage.accent)
                            }
                            Text("Curriculum")
                                .font(.system(.largeTitle, design: .serif, weight: .bold))
                            Text(store.state.courses.isEmpty ? "Organize subjects, lessons, and learning paths." : "\(store.state.courses.count) subject\(store.state.courses.count == 1 ? "" : "s") planned across your home.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 95)
                    }
                    .padding(.vertical, 4)

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
            }
            .sheet(isPresented: $showBuilder) { SequenceBuilderView() }
            .sheet(item: $selectedCourseForRoadmap) { course in
                CourseRoadmapDetailView(course: course, studentID: studentID)
            }
            .sheet(item: $editingCourse) { course in
                EditCourseView(course: course)
            }
            .sheet(isPresented: $showRebalanceSheet) {
                ScheduleRebalanceSheet(initialStudentID: studentID, initialCourseID: rebalanceTargetCourse?.id)
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
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    animateArt = true
                }
                if !isRunningUITests {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        sunGlowPulse = true
                    }
                }
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
                ZStack {
                    Circle()
                        .fill(Sage.soft)
                        .frame(width: 68, height: 68)
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Sage.accent)
                }
                .padding(.top, 12)

                Text("No subjects created yet")
                    .font(.headline.weight(.bold))
                Text("Create courses like Math, Reading, or Science to generate organized lesson sequences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    showBuilder = true
                } label: {
                    Label("Add First Subject", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Sage.accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(SpringScaleButtonStyle())
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var coursesSection: some View {
        Section {
            if studentCourses.isEmpty {
                Text("No subjects assigned to this learner yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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

                        Button {
                            rebalanceTargetCourse = course
                            showRebalanceSheet = true
                        } label: {
                            Label("Rebalance", systemImage: "sparkles")
                        }
                        .tint(.orange)
                        .accessibilityIdentifier("rebalanceCourse-\(course.title)")
                    }
                    .contextMenu {
                        Button {
                            rebalanceTargetCourse = course
                            showRebalanceSheet = true
                        } label: {
                            Label("Rebalance Schedule", systemImage: "sparkles")
                        }
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

            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                showBuilder = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Another Subject")
                            .font(.headline.weight(.semibold))
                        Text("Pace lessons with 4-day, 5-day, or custom rhythms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
                .foregroundStyle(Sage.accent)
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("addCourseInline")
        } header: {
            HStack(spacing: 8) {
                Text("Subjects & Curricula")
                Spacer()
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    rebalanceTargetCourse = nil
                    showRebalanceSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                        Text("Rebalance")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rebalanceHeaderButton")

                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    showBuilder = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                        Text("Add")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Sage.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Sage.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addCourseHeader")
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

    private var percent: Int { totalCount == 0 ? 0 : Int(progress * 100) }

    private var subjectTint: Color {
        let lower = course.title.lowercased()
        if lower.contains("math") || lower.contains("algebra") || lower.contains("geometry") { return Color.orange }
        if lower.contains("read") || lower.contains("lit") || lower.contains("english") { return Color.blue }
        if lower.contains("science") || lower.contains("bio") || lower.contains("chem") || lower.contains("physic") { return Sage.accent }
        if lower.contains("history") || lower.contains("geography") || lower.contains("social") { return Color.brown }
        if lower.contains("art") || lower.contains("draw") { return Color.purple }
        if lower.contains("music") { return Color.pink }
        if lower.contains("code") || lower.contains("program") { return Color.teal }
        return Sage.accent
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
                        .background(subjectTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

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

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(percent)%")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(progress >= 1.0 ? Color.orange : Sage.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    (progress >= 1.0 ? Color.orange : Sage.accent).opacity(0.12),
                                    in: Capsule()
                                )
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        Text("\(completedCount)/\(totalCount) done")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: progress)
                    .tint(progress >= 1.0 ? Color.orange : subjectTint)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progress)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(SpringScaleButtonStyle())
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
                Section("Grading Categories & Weighting") {
                    let existingCategories = store.gradeCategories(for: course.id)
                    if existingCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Equal Weighting (Default)")
                                .font(.subheadline.weight(.semibold))
                            Text("All assignments count equally toward the final course grade.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)

                        Menu {
                            Button("High School Core (50/30/20)") {
                                applyPreset([("Tests & Exams", 0.50), ("Quizzes", 0.30), ("Homework & Daily", 0.20)])
                            }
                            Button("STEM & Labs (40/35/25)") {
                                applyPreset([("Unit Exams", 0.40), ("Labs & Projects", 0.35), ("Daily Assignments", 0.25)])
                            }
                            Button("Elementary / Practice (30/30/40)") {
                                applyPreset([("Assessments", 0.30), ("Quizzes", 0.30), ("Classwork & Practice", 0.40)])
                            }
                        } label: {
                            Label("Apply Weighted Preset...", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Sage.accent)
                        }
                    } else {
                        let total = existingCategories.reduce(0) { $0 + $1.weight }
                        let totalPercent = Int(round(total * 100))
                        ForEach(existingCategories) { cat in
                            HStack {
                                Text(cat.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(round(cat.weight * 100)))%")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Sage.accent.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Sage.accent)
                            }
                        }

                        HStack {
                            Text("Total Category Weight")
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Text("\(totalPercent)%")
                                .font(.footnote.bold())
                                .foregroundStyle(totalPercent == 100 ? Color.green : Color.orange)
                        }

                        Button(role: .destructive) {
                            for cat in existingCategories {
                                store.deleteGradeCategory(id: cat.id)
                            }
                        } label: {
                            Label("Reset to Equal Weighting", systemImage: "arrow.counterclockwise")
                                .font(.footnote)
                        }
                    }

                    if let firstStudent = store.state.students.first {
                        NavigationLink {
                            GradeBookView(course: course, student: firstStudent)
                        } label: {
                            Label("Open Grade Book & Edit Ledger", systemImage: "slider.horizontal.3")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Sage.accent)
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

    private func applyPreset(_ list: [(String, Double)]) {
        for cat in store.gradeCategories(for: course.id) {
            store.deleteGradeCategory(id: cat.id)
        }
        for item in list {
            store.addGradeCategory(courseID: course.id, name: item.0, weight: item.1)
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


struct LessonDraft: Identifiable {
    let id = UUID()
    var title: String = ""
}

struct SequenceBuilderView: View {
    var body: some View {
        SequenceBuilderTabsView()
    }
}
