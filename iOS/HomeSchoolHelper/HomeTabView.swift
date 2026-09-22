import SwiftUI
import HomeschoolCore

struct HomeTabView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var hasDismissedOnboarding: Bool = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"] != nil && ProcessInfo.processInfo.environment["HSH_UI_TEST_ONBOARDING"] != "1" {
            return true
        }
        #endif
        return false
    }()

    var body: some View {
        Group {
            if let message = store.loadError {
                LoadFailureView(message: message, retry: store.load)
            } else if store.state.students.isEmpty && !hasDismissedOnboarding {
                OnboardingView(onExplore: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasDismissedOnboarding = true
                    }
                })
            } else {
                TabView {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.max") }
                        .accessibilityIdentifier("tabToday")
                    PlanView()
                        .tabItem { Label("Plan", systemImage: "calendar") }
                        .accessibilityIdentifier("tabPlan")
                    RecordsView()
                        .tabItem { Label("Records", systemImage: "folder") }
                        .accessibilityIdentifier("tabRecords")
                    FamilyView()
                        .tabItem { Label("Family", systemImage: "person.2") }
                        .accessibilityIdentifier("tabFamily")
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.state.students.isEmpty)
        .alert(item: $store.presentedError) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("OK")))
        }
    }
}

private struct LoadFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your school records couldn’t be opened", systemImage: "exclamationmark.triangle")
        } description: {
            Text("No changes can be made until the saved data is available. \(message)")
        } actions: {
            Button("Try Again", action: retry).buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var studentID: UUID?
    @State private var selectedDay = SchoolDate.today
    @State private var showNewStudent = false
    @State private var showNewCourse = false

    private var displayed: [Assignment] {
        store.state.assignments
            .filter { assignment in
                (studentID == nil || assignment.studentID == studentID) && assignment.scheduledDay == selectedDay
            }
            .sorted { lhs, rhs in
                (store.lesson(for: lhs.lessonID)?.sequence ?? 0) < (store.lesson(for: rhs.lessonID)?.sequence ?? 0)
            }
    }

    private var completedCount: Int { displayed.filter { $0.status == .completed }.count }

    /// Shows one actionable undated lesson per learner and course. This keeps
    /// flexible sequences separate from the selected day's dated progress.
    private var flexibleNext: [Assignment] {
        let eligible = store.state.assignments
            .filter {
                $0.scheduledDay == nil
                    && (studentID == nil || $0.studentID == studentID)
                    && ($0.status == .planned || $0.status == .inProgress)
            }
            .sorted { lhs, rhs in
                let lhsStudent = store.student(for: lhs.studentID)?.name ?? ""
                let rhsStudent = store.student(for: rhs.studentID)?.name ?? ""
                if lhsStudent != rhsStudent { return lhsStudent < rhsStudent }

                let lhsCourse = store.lesson(for: lhs.lessonID).flatMap(store.course(for:))?.title ?? ""
                let rhsCourse = store.lesson(for: rhs.lessonID).flatMap(store.course(for:))?.title ?? ""
                if lhsCourse != rhsCourse { return lhsCourse < rhsCourse }

                return (store.lesson(for: lhs.lessonID)?.sequence ?? 0) < (store.lesson(for: rhs.lessonID)?.sequence ?? 0)
            }

        var representedCourses = Set<String>()
        return eligible.compactMap { assignment in
            let courseID = store.lesson(for: assignment.lessonID)?.courseID ?? assignment.lessonID
            let key = "\(assignment.studentID.uuidString)-\(courseID.uuidString)"
            return representedCourses.insert(key).inserted ? assignment : nil
        }
    }

    private var totalCompletedAssignments: Int {
        store.state.assignments.filter { $0.status == .completed }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(SchoolDate.long(selectedDay)).font(.caption).foregroundStyle(.secondary)
                    Text("A little learning.\nA lovely day.")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    DayPicker(day: $selectedDay)
                    StudentScopePicker(students: store.state.students, selection: $studentID)

                    if store.state.students.isEmpty {
                        emptyStudentsView
                    } else if store.state.courses.isEmpty {
                        emptyCoursesView
                    } else {
                        mainScheduleContent
                    }
                }
                .padding()
            }
            .background(Sage.background.ignoresSafeArea())
            .navigationTitle("Today")
            .toolbar { SaveStatusToolbar() }
            .sheet(isPresented: $showNewStudent) { AddStudentView() }
            .sheet(isPresented: $showNewCourse) { SequenceBuilderView() }
        }
    }

    @ViewBuilder
    private var emptyStudentsView: some View {
        VStack(spacing: 14) {
            EmptyCard(icon: "person.badge.plus", title: "Start with your learners", detail: "Add a learner to begin planning courses and recording daily learning.")
            Button {
                showNewStudent = true
            } label: {
                Label("Add First Learner", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Sage.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("todayAddStudent")
        }
    }

    @ViewBuilder
    private var emptyCoursesView: some View {
        let activeLearnerName = studentID.flatMap { store.student(for: $0)?.name } ?? store.state.students.first?.name ?? "Your learner"
        VStack(alignment: .leading, spacing: 14) {
            Text("\(activeLearnerName) is all set!")
                .font(.title3.bold())
            Text("Now let's add a subject (like Math, Reading, or Science) so lessons appear on your checklist.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showNewCourse = true
            } label: {
                Label("Add First Subject", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Sage.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("todayAddFirstCourse")
        }
        .padding(20)
        .background(Sage.soft, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var mainScheduleContent: some View {
        if totalCompletedAssignments < 2 {
            GettingStartedGuideCard(onAddCourse: { showNewCourse = true })
        }

        let overdue = overdueAssignments
        if selectedDay == SchoolDate.today && !overdue.isEmpty {
            OverdueCatchUpCard(overdueCount: overdue.count) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    _ = store.rescheduleOverdue(to: SchoolDate.today, studentID: studentID)
                }
            }
        }

        ProgressCard(completed: completedCount, total: displayed.count)

        HStack {
            Text("Scheduled work").font(.title2.bold())
            Spacer()
            Text("\(displayed.count) scheduled").foregroundStyle(.secondary)
        }

        if displayed.isEmpty && flexibleNext.isEmpty {
            VStack(spacing: 12) {
                EmptyCard(icon: "calendar.badge.checkmark", title: "No lessons for this date", detail: "You have completed all scheduled lessons, or nothing is scheduled for today.")
                Button {
                    showNewCourse = true
                } label: {
                    Label("Add another subject or lessons", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                }
            }
        } else {
            if !displayed.isEmpty {
                VStack(spacing: 10) {
                    ForEach(displayed) { assignment in
                        AssignmentCard(assignment: assignment)
                    }
                }
            }

            if !flexibleNext.isEmpty {
                HStack {
                    Text("Flexible next work").font(.title2.bold())
                    Spacer()
                    Text("Work at your pace").foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(flexibleNext) { assignment in
                        AssignmentCard(assignment: assignment)
                    }
                }
            }
        }

        if !store.state.students.isEmpty {
            TodayAttendanceCard(studentID: studentID, selectedDay: selectedDay)
        }
    }

    private var overdueAssignments: [Assignment] {
        store.overdueAssignments(asOf: selectedDay, studentID: studentID)
    }
}

private struct OverdueCatchUpCard: View {
    let overdueCount: Int
    let onCatchUp: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(overdueCount) Past Lesson\(overdueCount == 1 ? "" : "s") Unfinished")
                    .font(.subheadline.bold())
                Text("Catch up with a single tap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button("Move to Today", action: onCatchUp)
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .accessibilityIdentifier("catchUpOverdue")
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TodayAttendanceCard: View {
    @EnvironmentObject private var store: HomeschoolStore
    let studentID: UUID?
    let selectedDay: String
    @State private var hours: Double = 3.0
    @State private var justConfirmed = false

    private var activeStudents: [Student] {
        if let studentID, let student = store.student(for: studentID) {
            return [student]
        }
        return store.state.students
    }

    private var unrecordedStudents: [Student] {
        activeStudents.filter { store.attendanceEntry(for: $0.id, day: selectedDay) == nil }
    }

    private var totalConfirmedToday: Int {
        activeStudents.compactMap { store.attendanceEntry(for: $0.id, day: selectedDay)?.minutes }.reduce(0, +)
    }

    var body: some View {
        if selectedDay == SchoolDate.today && !activeStudents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if unrecordedStudents.isEmpty || justConfirmed {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Sage.accent)
                        Text("Today's Attendance Recorded (\(Hours(minutes: totalConfirmedToday)))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Sage.accent)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wrap Up Today's School")
                                .font(.subheadline.bold())
                            Text("Confirm attendance for \(unrecordedStudents.map(\.name).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack {
                        Stepper(value: $hours, in: 0.5...12.0, step: 0.5) {
                            Text("\(String(format: "%.1f", hours)) hrs (\(Int(hours * 60))m)")
                                .font(.subheadline.weight(.semibold))
                        }

                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            let minutes = Int(hours * 60)
                            for student in unrecordedStudents {
                                _ = store.confirmAttendance(studentID: student.id, day: selectedDay, minutes: minutes)
                            }
                            withAnimation {
                                justConfirmed = true
                            }
                        } label: {
                            Text("Confirm")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Sage.accent, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                        .accessibilityIdentifier("quickConfirmAttendance")
                    }
                }
            }
            .padding(14)
            .background(Sage.soft, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct GettingStartedGuideCard: View {
    @EnvironmentObject private var store: HomeschoolStore
    var onAddCourse: () -> Void
    @State private var isDismissed = false

    private var hasStudents: Bool { !store.state.students.isEmpty }
    private var hasCourses: Bool { !store.state.courses.isEmpty }
    private var hasCompletedLesson: Bool { store.state.assignments.contains { $0.status == .completed } }
    private var hasAttendance: Bool { !store.state.attendance.isEmpty }

    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Getting Started", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Sage.accent)
                    Spacer()
                    Button {
                        withAnimation { isDismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    GuideStepRow(title: "Add your learner", isDone: hasStudents)
                    GuideStepRow(title: "Add your first subject", isDone: hasCourses)
                    GuideStepRow(title: "Check off your first lesson", isDone: hasCompletedLesson, hint: "Tap any lesson circle below")
                    GuideStepRow(title: "Record today's attendance", isDone: hasAttendance, hint: "Visit the Records tab")
                }
            }
            .padding(18)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct GuideStepRow: View {
    let title: String
    let isDone: Bool
    var hint: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? Sage.accent : .secondary)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(isDone ? .regular : .semibold))
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                if !isDone, let hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AssignmentCard: View {
    @EnvironmentObject private var store: HomeschoolStore
    let assignment: Assignment
    @State private var showStatus = false

    private var lesson: Lesson? { store.lesson(for: assignment.lessonID) }
    private var statusTitle: String { assignment.status.readable }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 1-Tap Quick Check Button
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = store.toggleAssignmentStatus(assignment)
                }
            } label: {
                Image(systemName: assignment.status.symbol)
                    .font(.title3)
                    .foregroundStyle(assignment.status == .completed ? Sage.accent : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.status == .completed ? "Mark incomplete" : "Mark complete")
            .accessibilityIdentifier("toggleStatus-\(lesson?.title ?? "missing")")

            // Card Body - opens detail sheet
            Button {
                showStatus = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson?.title ?? "Missing lesson")
                        .font(.headline)
                        .strikethrough(assignment.status == .completed)
                        .foregroundStyle(assignment.status == .completed ? .secondary : .primary)
                    Text([store.student(for: assignment.studentID)?.name, lesson.flatMap(store.course(for:))?.title]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let completedDay = assignment.completedDay {
                        Text("Completed \(SchoolDate.short(completedDay))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(assignment.status == .completed ? Sage.accent : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                _ = store.toggleAssignmentStatus(assignment)
            } label: {
                Label(assignment.status == .completed ? "Mark Planned" : "Mark Completed", systemImage: assignment.status == .completed ? "circle" : "checkmark.circle.fill")
            }

            if assignment.scheduledDay != nil {
                Button {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    _ = store.rescheduleAssignment(assignment, to: SchoolDate.string(tomorrow))
                } label: {
                    Label("Push to Tomorrow", systemImage: "arrow.right.circle")
                }

                Button {
                    _ = store.rescheduleAssignment(assignment, to: nil)
                } label: {
                    Label("Make Flexible (Undated)", systemImage: "calendar.badge.minus")
                }
            } else {
                Button {
                    _ = store.rescheduleAssignment(assignment, to: SchoolDate.today)
                } label: {
                    Label("Move to Today", systemImage: "calendar.badge.plus")
                }
            }

            Button {
                showStatus = true
            } label: {
                Label("Edit Status Details...", systemImage: "slider.horizontal.3")
            }
        }
        .accessibilityLabel("\(lesson?.title ?? "Lesson") for \(store.student(for: assignment.studentID)?.name ?? "learner"), \(statusTitle)")
        .accessibilityIdentifier("assignment-\(store.student(for: assignment.studentID)?.name ?? "unknown")-\(lesson?.title ?? "missing")")
        .sheet(isPresented: $showStatus) { AssignmentStatusSheet(assignment: assignment) }
    }
}

private struct AssignmentStatusSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let assignment: Assignment
    @State private var status: AssignmentStatus
    @State private var completionDate: Date

    init(assignment: Assignment) {
        self.assignment = assignment
        _status = State(initialValue: assignment.status)
        _completionDate = State(initialValue: SchoolDate.date(assignment.completedDay) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Lesson status") {
                    Picker("Status", selection: $status) {
                        ForEach(AssignmentStatus.allCases, id: \.self) { Text($0.readable).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("assignmentStatusPicker")
                }
                if status == .completed {
                    Section("Completion") {
                        DatePicker("Completed on", selection: $completionDate, displayedComponents: .date)
                        Text("Completing a lesson does not record attendance or a grade.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Update Lesson")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.setStatus(assignment, status: status, completedDay: status == .completed ? SchoolDate.string(completionDate) : nil) { dismiss() }
                    }
                    .accessibilityIdentifier("saveAssignmentStatus")
                }
            }
        }
    }
}

struct PlanView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var studentID: UUID?
    @State private var showBuilder = false

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
                CourseRowView(course: course, studentID: studentID)
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
}

private struct CourseRowView: View {
    @EnvironmentObject private var store: HomeschoolStore
    let course: Course
    let studentID: UUID?

    var body: some View {
        let lessons = store.state.lessons.filter { $0.courseID == course.id }
        let courseAssignments = store.state.assignments.filter { assignment in
            lessons.map(\.id).contains(assignment.lessonID) && (studentID == nil || assignment.studentID == studentID)
        }
        let completed = courseAssignments.filter { $0.status == .completed }.count
        let total = courseAssignments.count

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(course.title)
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total) done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Sage.accent)
            }
            Text("\(lessons.count) lessons total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private enum LessonActivityType: String, CaseIterable, Identifiable {
    case reading = "📖"
    case practice = "✏️"
    case lab = "🔬"
    case quiz = "📝"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .reading: return "Reading"
        case .practice: return "Practice"
        case .lab: return "Lab"
        case .quiz: return "Quiz"
        }
    }

    var next: LessonActivityType {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return .reading }
        return all[(idx + 1) % all.count]
    }
}

private struct DraftLesson: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var activityType: LessonActivityType = .reading
    var durationMinutes: Int = 30
    var notes: String = ""
}

private struct RoadmapMilestoneCard: View {
    @Binding var lesson: DraftLesson
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Milestone spine rail
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Sage.accent.opacity(0.35))
                    .frame(width: 2, height: 14)

                ZStack {
                    Circle()
                        .stroke(Sage.accent, lineWidth: 2)
                        .background(Circle().fill(Color(.systemBackground)))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Sage.accent)
                        .frame(width: 8, height: 8)
                }

                Rectangle()
                    .fill(isLast ? Color.clear : Sage.accent.opacity(0.35))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            // Milestone Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    // Activity Icon Pill (cycles on tap)
                    Button {
                        lesson.activityType = lesson.activityType.next
                    } label: {
                        HStack(spacing: 4) {
                            Text(lesson.activityType.rawValue)
                                .font(.subheadline)
                            Text(lesson.activityType.name)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Sage.accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Sage.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    // Lesson Title (Large, Bold & Readable)
                    TextField("Lesson title", text: $lesson.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 4)

                    // Duration pill (cycles 20 -> 30 -> 45 -> 60)
                    Button {
                        cycleDuration()
                    } label: {
                        Text("\(lesson.durationMinutes)m")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Sage.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Sage.accent.opacity(0.14)))
                    }
                    .buttonStyle(.plain)

                    // Delete button
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete lesson")
                }

                // Secondary notes / materials
                TextField("Notes or materials (e.g. Chapter 1, Kit 4)", text: $lesson.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func cycleDuration() {
        let options = [20, 30, 45, 60]
        if let idx = options.firstIndex(of: lesson.durationMinutes) {
            lesson.durationMinutes = options[(idx + 1) % options.count]
        } else {
            lesson.durationMinutes = 30
        }
    }
}

private struct SequenceBuilderView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var courseTitle = ""
    @State private var selectedStudents = Set<UUID>()
    @State private var draftLessons: [DraftLesson] = [
        DraftLesson(title: "Lesson 1: Introduction", activityType: .reading, durationMinutes: 25, notes: "Core Reading"),
        DraftLesson(title: "Lesson 2: Core Concepts", activityType: .practice, durationMinutes: 30, notes: "Workbook Practice"),
        DraftLesson(title: "Lesson 3: Hands-on Lab", activityType: .lab, durationMinutes: 45, notes: "Activity Kit"),
        DraftLesson(title: "Lesson 4: Review & Application", activityType: .practice, durationMinutes: 30, notes: "Review Problems"),
        DraftLesson(title: "Lesson 5: Unit Checkpoint", activityType: .quiz, durationMinutes: 25, notes: "Check-in Quiz")
    ]
    @State private var showBulkEditor = false
    @State private var datesLessons = true
    @State private var startDate = Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var bulkOutlineText = ""

    private let weekdayNames = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]

    private var validLessonTitles: [String] {
        draftLessons
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var estimatedWeeks: Int {
        let activeDays = max(1, weekdays.count)
        return max(1, Int(ceil(Double(validLessonTitles.count) / Double(activeDays))))
    }

    private var projectedEndDateString: String? {
        guard datesLessons, !validLessonTitles.isEmpty, !weekdays.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        var date = startDate
        var scheduled = 0
        while scheduled < validLessonTitles.count {
            if weekdays.contains(calendar.component(.weekday, from: date)) {
                scheduled += 1
            }
            if scheduled == validLessonTitles.count { break }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        if store.presentedError != nil {
                            SaveErrorBanner()
                        }

                        heroCourseCard
                        roadmapSection
                        learnersSection
                        scheduleSection
                        bulkOutlineSection

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(Color(.systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)

                floatingBottomDock
            }
            .navigationTitle("Curriculum Roadmap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
            .sheet(isPresented: $showBulkEditor) {
                BulkLessonsSheet(
                    isPresented: $showBulkEditor,
                    draftLessons: $draftLessons,
                    initialText: draftLessons.map(\.title).joined(separator: "\n")
                )
            }
            .onAppear {
                if selectedStudents.isEmpty, let first = store.state.students.first {
                    selectedStudents.insert(first.id)
                }
                syncBulkOutlineText()
            }
        }
    }

    // MARK: - Hero Course Card
    @ViewBuilder
    private var heroCourseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COURSE IDENTITY")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Sage.accent)

                    TextField("Subject title (e.g. Science)", text: $courseTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("courseTitle")
                }

                Spacer()

                // Circular visual progress & count ring (Large & Legible)
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 5.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, max(0.08, Double(validLessonTitles.count) / 36.0))))
                        .stroke(Sage.accent, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(validLessonTitles.count)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Sage.accent)
                        Text("lessons")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 58, height: 58)
            }

            // Summary metadata pill (Readable Subheadline)
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("\(validLessonTitles.count) Lessons • \(estimatedWeeks) Weeks")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Sage.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Sage.accent.opacity(0.14)))

                if datesLessons, let end = projectedEndDateString {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Ends \(end)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Roadmap Section (Linear Milestone Rail)
    @ViewBuilder
    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Curriculum Roadmap")
                    .font(.headline)
                Spacer()
                if !draftLessons.isEmpty {
                    Button("Clear All") {
                        withAnimation {
                            draftLessons.removeAll()
                            syncBulkOutlineText()
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.red)
                }
            }

            // Unit 1 Gateway Header
            unit1Banner

            // Milestone Nodes
            if draftLessons.isEmpty {
                emptyMilestonesPrompt
            } else {
                VStack(spacing: 0) {
                    ForEach(draftLessons.indices, id: \.self) { idx in
                        RoadmapMilestoneCard(
                            lesson: $draftLessons[idx],
                            index: idx,
                            isFirst: idx == 0,
                            isLast: idx == draftLessons.count - 1,
                            onDelete: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    draftLessons.remove(at: idx)
                                    syncBulkOutlineText()
                                }
                            }
                        )
                    }

                    // Inline Spine Extension Node
                    inlineSpineAdderNode
                }
            }
        }
    }

    @ViewBuilder
    private var unit1Banner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 42, height: 42)
                Image(systemName: "rocket.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("UNIT 1")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Core Curriculum Sequence")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("\(validLessonTitles.count) lessons")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.25)))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Sage.accent, Sage.accent.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Sage.accent.opacity(0.18), radius: 6, y: 3)
    }

    @ViewBuilder
    private var inlineSpineAdderNode: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Sage.accent.opacity(0.35))
                    .frame(width: 2, height: 14)

                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                        .foregroundStyle(Sage.accent)
                        .frame(width: 22, height: 22)
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Sage.accent)
                }
            }
            .frame(width: 20)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    addSingleLesson()
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text("Add Next Lesson")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(Sage.accent)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4]))
                        .foregroundStyle(Sage.accent.opacity(0.5))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addLessonRow")
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var emptyMilestonesPrompt: some View {
        VStack(spacing: 10) {
            Text("No milestone lessons created yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                addSingleLesson()
            } label: {
                Label("Add First Lesson", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(Sage.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Learners Section
    @ViewBuilder
    private var learnersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assigned Learners")
                .font(.headline)

            VStack(spacing: 0) {
                if store.state.students.isEmpty {
                    Text("Add a learner on the Family tab first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(14)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if student.id != store.state.students.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // MARK: - Schedule Section
    @ViewBuilder
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schedule & Cadence")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Put lessons on a calendar", isOn: $datesLessons)
                    .accessibilityIdentifier("datedLessonSchedule")

                if datesLessons {
                    Divider()

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active Days").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 6)], spacing: 6) {
                            ForEach(weekdayNames, id: \.0) { weekday in
                                Button(weekday.1) {
                                    if weekdays.contains(weekday.0) {
                                        weekdays.remove(weekday.0)
                                    } else {
                                        weekdays.insert(weekday.0)
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(weekdays.contains(weekday.0) ? Sage.accent : Color(.tertiarySystemFill))
                                )
                                .foregroundStyle(weekdays.contains(weekday.0) ? .white : .primary)
                                .accessibilityLabel("\(weekday.1) school day")
                                .accessibilityValue(weekdays.contains(weekday.0) ? "Selected" : "Not selected")
                            }
                        }
                    }

                    if let projectedEndDateString {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Sage.accent)
                            Text("Projected finish: \(projectedEndDateString)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Sage.accent)
                        }
                        .padding(.top, 2)
                    }
                } else {
                    Text("Flexible lessons will be available in Plan without a date.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // MARK: - Bulk Outline Section (For Paste & Automated UI Test Compatibility)
    @ViewBuilder
    private var bulkOutlineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Paste Syllabus / Bulk Text", systemImage: "doc.plaintext")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply Text") {
                    applyBulkOutline()
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Sage.accent)
            }

            TextEditor(text: $bulkOutlineText)
                .frame(minHeight: 70)
                .padding(8)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Lesson titles")
                .accessibilityIdentifier("lessonTitles")
                .onChange(of: bulkOutlineText) { _, newText in
                    applyBulkOutline(from: newText)
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Floating Bottom Action Dock
    @ViewBuilder
    private var floatingBottomDock: some View {
        HStack(spacing: 10) {
            Button("+ 5") { addBatch(5) }
                .buttonStyle(.bordered)
                .tint(Sage.accent)
                .font(.caption.weight(.bold))

            Button("+ 10") { addBatch(10) }
                .buttonStyle(.bordered)
                .tint(Sage.accent)
                .font(.caption.weight(.bold))

            Button {
                showBulkEditor = true
            } label: {
                Label("Bulk", systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("openBulkEditor")

            Spacer()

            Button("Save Curriculum") {
                saveCourse()
            }
            .buttonStyle(.borderedProminent)
            .tint(Sage.accent)
            .font(.subheadline.weight(.bold))
            .disabled(store.state.students.isEmpty || validLessonTitles.isEmpty || courseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("saveCourse")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Actions
    private func addSingleLesson() {
        let nextNumber = draftLessons.count + 1
        draftLessons.append(DraftLesson(title: "Lesson \(nextNumber)"))
        syncBulkOutlineText()
    }

    private func addBatch(_ count: Int) {
        let currentCount = draftLessons.count
        for i in 1...count {
            draftLessons.append(DraftLesson(title: "Lesson \(currentCount + i)"))
        }
        syncBulkOutlineText()
    }

    private func syncBulkOutlineText() {
        bulkOutlineText = draftLessons.map(\.title).joined(separator: "\n")
    }

    private func applyBulkOutline(from text: String? = nil) {
        let source = text ?? bulkOutlineText
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !lines.isEmpty {
            let currentTitles = draftLessons.map(\.title)
            if lines != currentTitles {
                draftLessons = lines.map { DraftLesson(title: $0) }
            }
        }
    }

    private func saveCourse() {
        if store.addCourse(
            title: courseTitle,
            studentIDs: Array(selectedStudents),
            lessonTitles: validLessonTitles,
            startDay: datesLessons ? SchoolDate.string(startDate) : nil,
            weekdays: weekdays
        ) {
            dismiss()
        }
    }
}

private struct BulkLessonsSheet: View {
    @Binding var isPresented: Bool
    @Binding var draftLessons: [DraftLesson]
    @State private var text: String

    init(isPresented: Binding<Bool>, draftLessons: Binding<[DraftLesson]>, initialText: String) {
        self._isPresented = isPresented
        self._draftLessons = draftLessons
        self._text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Paste or Edit Lesson Titles") {
                    Text("Type or paste lesson titles, one per line.").font(.footnote).foregroundStyle(.secondary)
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("Bulk Lesson Editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let lines = text.components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        draftLessons = lines.map { DraftLesson(title: $0) }
                        isPresented = false
                    }
                    .font(.headline)
                }
            }
        }
    }
}

struct RecordsView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var showAttendance = false
    @State private var showActivity = false

    private var totalMinutes: Int { store.state.attendance.reduce(0) { $0 + $1.minutes } }
    private var activityMinutes: Int { store.state.activities.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Everything you’ve done").font(.caption).foregroundStyle(.secondary)
                        Text("Real progress, kept locally.").font(.title2.bold())
                        HStack {
                            Metric(title: "Attendance", value: "\(store.state.attendance.count) learner-days")
                            Metric(title: "Confirmed", value: Hours(minutes: totalMinutes))
                            Metric(title: "Activities", value: Hours(minutes: activityMinutes))
                        }
                    }
                    .padding(.vertical, 8)
                }
                Section("Learning records") {
                    Button { showAttendance = true } label: { Label("Attendance & hours", systemImage: "checkmark.circle") }
                        .accessibilityIdentifier("openAttendance")
                    Button { showActivity = true } label: { Label("Log retrospective activity", systemImage: "clock.arrow.circlepath") }
                        .accessibilityIdentifier("addActivity")
                }
                Section("Recent activity") {
                    if store.state.activities.isEmpty && store.state.attendance.isEmpty {
                        Text("Confirmed attendance and activities will appear here.").foregroundStyle(.secondary)
                    }
                    ForEach(store.state.activities.sorted { $0.day > $1.day }.prefix(12)) { activity in
                        VStack(alignment: .leading) {
                            Text(activity.title)
                            Text("\(store.student(for: activity.studentID)?.name ?? "Unknown learner") · \(SchoolDate.short(activity.day)) · \(Hours(minutes: activity.minutes))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Records")
            .toolbar { SaveStatusToolbar() }
            .sheet(isPresented: $showAttendance) { AttendanceView() }
            .sheet(isPresented: $showActivity) { ActivityLogView() }
        }
    }
}

private struct AttendanceView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var studentID: UUID?
    @State private var minutes = 180

    private var entries: [AttendanceEntry] { store.state.attendance.sorted { $0.day > $1.day } }
    private var totalMinutes: Int { store.state.attendance.reduce(0) { $0 + $1.minutes } }
    private var recordedDateCount: Int { Set(entries.map(\.day)).count }

    var body: some View {
        NavigationStack {
            List {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("All recorded attendance") {
                    LabeledContent("Confirmed time", value: Hours(minutes: totalMinutes))
                    LabeledContent("Learner-days recorded", value: "\(entries.count)")
                    LabeledContent("Recorded dates", value: "\(recordedDateCount)")
                }
                Section("Confirm a day") {
                    if store.state.students.isEmpty {
                        Text("Add a learner before confirming attendance.").foregroundStyle(.secondary)
                    } else {
                        Picker("Learner", selection: $studentID) {
                            Text("Choose learner").tag(UUID?.none)
                            ForEach(store.state.students) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .accessibilityIdentifier("attendanceLearner")
                        DatePicker("Day", selection: $day, displayedComponents: .date)
                            .accessibilityIdentifier("attendanceDay")
                        TextField("Instructional minutes", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("attendanceMinutes")
                        Button("Confirm attendance") {
                            if let studentID { _ = store.confirmAttendance(studentID: studentID, day: SchoolDate.string(day), minutes: minutes) }
                        }
                        .disabled(studentID == nil || !(1...1440).contains(minutes))
                        .accessibilityIdentifier("confirmAttendance")
                        Text("This confirms the total instructional time for the learner and day. Saving it again updates that day; activities do not add attendance automatically.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Recorded days") {
                    if entries.isEmpty { Text("No attendance confirmed yet.").foregroundStyle(.secondary) }
                    ForEach(entries) { entry in
                        LabeledContent("\(store.student(for: entry.studentID)?.name ?? "Unknown learner") · \(SchoolDate.short(entry.day))", value: Hours(minutes: entry.minutes))
                    }
                }
            }
            .navigationTitle("Attendance & Hours")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss.callAsFunction) } }
            .onChange(of: studentID) { prefillMinutes() }
            .onChange(of: day) { prefillMinutes() }
        }
    }

    private func prefillMinutes() {
        guard let studentID,
              let entry = store.state.attendance.first(where: {
                  $0.studentID == studentID && $0.day == SchoolDate.string(day)
              }) else {
            minutes = 180
            return
        }
        minutes = entry.minutes
    }
}

private struct ActivityLogView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedStudents = Set<UUID>()
    @State private var day = Date()
    @State private var minutes = 30

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Activity") {
                    TextField("What did you learn?", text: $title)
                        .accessibilityIdentifier("activityTitle")
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                        .accessibilityIdentifier("activityDay")
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...1440)
                        .accessibilityIdentifier("activityMinutes")
                }
                Section("Learners") {
                    ForEach(store.state.students) { student in
                        Toggle(student.name, isOn: Binding(
                            get: { selectedStudents.contains(student.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedStudents.insert(student.id)
                                } else {
                                    selectedStudents.remove(student.id)
                                }
                            }
                        ))
                    }
                    Text("One activity record will be created for each selected learner. This does not confirm attendance.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.logActivity(title: title, studentIDs: Array(selectedStudents), day: SchoolDate.string(day), minutes: minutes) { dismiss() }
                    }
                    .accessibilityIdentifier("saveActivity")
                }
            }
        }
    }
}

struct FamilyView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var showAddStudent = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your learning team").font(.caption).foregroundStyle(.secondary)
                    Text("Family").font(.largeTitle.bold())
                }
                Section("Learners") {
                    if store.state.students.isEmpty {
                        ContentUnavailableView("No learners yet", systemImage: "person.2.badge.plus", description: Text("Add each learner to start planning independent work."))
                    } else {
                        ForEach(store.state.students) { student in
                            HStack {
                                Image(systemName: "person.fill").foregroundStyle(Sage.accent)
                                VStack(alignment: .leading) {
                                    Text(student.name)
                                    Text(student.gradeLevel.isEmpty ? "Grade level not set" : student.gradeLevel)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button("Add Learner", systemImage: "plus") { showAddStudent = true }
                        .accessibilityIdentifier("addStudent")
                }
                Section("Your data") {
                    Label("Saved on this device", systemImage: "internaldrive")
                    Text("This milestone keeps school records locally. It does not create accounts, billing, grades, transcripts, or cloud sync.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Family")
            .toolbar { SaveStatusToolbar() }
            .sheet(isPresented: $showAddStudent) { AddStudentView() }
        }
    }
}

private struct AddStudentView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gradeLevel = ""

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Learner details") {
                    TextField("Name", text: $name).accessibilityIdentifier("studentName")
                    TextField("Grade level", text: $gradeLevel).accessibilityIdentifier("studentGrade")
                }
            }
            .navigationTitle("Add Learner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if store.addStudent(name: name, gradeLevel: gradeLevel) { dismiss() }
                    }
                    .accessibilityIdentifier("saveStudent")
                }
            }
        }
    }
}

private struct SaveErrorBanner: View {
    @EnvironmentObject private var store: HomeschoolStore

    var body: some View {
        if let error = store.presentedError {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title).font(.headline)
                    Text(error.message).font(.footnote)
                }
                Spacer(minLength: 0)
                Button("Dismiss") { store.presentedError = nil }
                    .font(.caption.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("saveError")
        }
    }
}

private struct StudentScopePicker: View {
    @EnvironmentObject private var store: HomeschoolStore
    let students: [Student]
    @Binding var selection: UUID?

    var body: some View {
        if !students.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All Learners" pill
                    let allAssignments = store.state.assignments.filter { $0.scheduledDay == SchoolDate.today }
                    let allCompleted = allAssignments.filter { $0.status == .completed }.count
                    let isAllSelected = selection == nil

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = nil }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("All")
                                .font(.subheadline.weight(isAllSelected ? .semibold : .regular))
                            if !allAssignments.isEmpty {
                                Text("\(allCompleted)/\(allAssignments.count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isAllSelected ? Color.white.opacity(0.25) : Sage.accent.opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isAllSelected ? Sage.accent : Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .foregroundStyle(isAllSelected ? .white : .primary)
                    }
                    .accessibilityLabel("Filter: All learners")
                    .accessibilityIdentifier("filterAllLearners")

                    // Individual Learner pills
                    ForEach(students) { student in
                        let isSelected = selection == student.id
                        let studentAssignments = store.state.assignments.filter { $0.studentID == student.id && $0.scheduledDay == SchoolDate.today }
                        let studentCompleted = studentAssignments.filter { $0.status == .completed }.count

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selection = student.id }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text(student.name)
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                if !studentAssignments.isEmpty {
                                    Text("\(studentCompleted)/\(studentAssignments.count)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? Color.white.opacity(0.25) : Sage.accent.opacity(0.15), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Sage.accent : Color(uiColor: .secondarySystemBackground), in: Capsule())
                            .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .accessibilityLabel("Filter: \(student.name)")
                        .accessibilityIdentifier("filterStudent-\(student.name)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct DayPicker: View {
    @Binding var day: String

    var body: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous day")
            Spacer()
            Text(SchoolDate.short(day)).font(.headline)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next day")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func shift(_ amount: Int) {
        guard let date = SchoolDate.date(day), let newDate = Calendar.current.date(byAdding: .day, value: amount, to: date) else { return }
        day = SchoolDate.string(newDate)
    }
}

private struct ProgressCard: View {
    let completed: Int
    let total: Int
    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Family progress").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            Text("\(completed) of \(total) lessons complete").font(.title3.bold())
            ProgressView(value: progress).tint(Sage.accent)
                .accessibilityLabel("Family progress")
                .accessibilityValue("\(completed) of \(total) lessons complete")
        }
        .padding()
        .background(Sage.soft, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct EmptyCard: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(detail))
            .frame(maxWidth: .infinity)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct Metric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SaveStatusToolbar: ToolbarContent {
    @EnvironmentObject private var store: HomeschoolStore
    var body: some ToolbarContent {
        ToolbarItem(placement: .status) {
            Label(store.isSaving ? "Saving" : "Saved locally", systemImage: store.isSaving ? "arrow.triangle.2.circlepath" : "checkmark.icloud")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private extension AssignmentStatus {
    var readable: String {
        switch self {
        case .planned: "Planned"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .skipped: "Skipped"
        }
    }

    var symbol: String {
        switch self {
        case .planned: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .completed: "checkmark.circle.fill"
        case .skipped: "forward.fill"
        }
    }
}

private func Hours(minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)m" }
    if remainder == 0 { return "\(hours)h" }
    return "\(hours)h \(remainder)m"
}
