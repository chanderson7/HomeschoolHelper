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
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .accessibilityIdentifier("tabSettings")
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
                let firstIncompleteIndex = displayed.firstIndex { $0.status != .completed }
                VStack(spacing: 0) {
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { index, assignment in
                        AssignmentCard(
                            assignment: assignment,
                            isFirst: index == 0,
                            isLast: index == displayed.count - 1,
                            isActive: index == firstIncompleteIndex,
                            showTimelineSpine: true
                        )
                    }
                }
            }

            if !flexibleNext.isEmpty {
                HStack {
                    Text("Flexible next work").font(.title2.bold())
                    Spacer()
                    Text("Work at your pace").foregroundStyle(.secondary)
                }

                let firstIncompleteFlexibleIndex = flexibleNext.firstIndex { $0.status != .completed }
                VStack(spacing: 0) {
                    ForEach(Array(flexibleNext.enumerated()), id: \.element.id) { index, assignment in
                        AssignmentCard(
                            assignment: assignment,
                            isFirst: index == 0,
                            isLast: index == flexibleNext.count - 1,
                            isActive: index == firstIncompleteFlexibleIndex,
                            showTimelineSpine: true
                        )
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
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(overdueCount) Past Lesson\(overdueCount == 1 ? "" : "s") Unfinished")
                    .font(.headline.weight(.bold))
                Text("Catch up with a single tap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button("Move to Today", action: onCatchUp)
                .font(.subheadline.bold())
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .accessibilityIdentifier("catchUpOverdue")
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
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
            VStack(alignment: .leading, spacing: 12) {
                if unrecordedStudents.isEmpty || justConfirmed {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(Sage.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Attendance Recorded (\(Hours(minutes: totalConfirmedToday)))")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Sage.accent)
                            Text("Confirmed for \(activeStudents.map(\.name).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wrap Up Today's School")
                                .font(.headline.weight(.bold))
                            Text("Confirm attendance for \(unrecordedStudents.map(\.name).joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 14) {
                        Stepper(value: $hours, in: 0.5...12.0, step: 0.5) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .foregroundStyle(Sage.accent)
                                Text("\(String(format: "%.1f", hours)) hrs (\(Int(hours * 60))m)")
                                    .font(.subheadline.weight(.bold))
                            }
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Sage.accent, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                        .accessibilityIdentifier("quickConfirmAttendance")
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
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

    static func detect(from title: String) -> LessonActivityType {
        let lower = title.lowercased()
        if lower.contains("quiz") || lower.contains("test") || lower.contains("exam") || lower.contains("checkpoint") {
            return .quiz
        } else if lower.contains("lab") || lower.contains("experiment") || lower.contains("project") || lower.contains("investigat") {
            return .lab
        } else if lower.contains("read") || lower.contains("chapter") || lower.contains("intro") || lower.contains("story") || lower.contains("book") {
            return .reading
        } else {
            return .practice
        }
    }
}

private struct AssignmentCard: View {
    @EnvironmentObject private var store: HomeschoolStore
    let assignment: Assignment
    var isFirst: Bool = false
    var isLast: Bool = false
    var isActive: Bool = false
    var showTimelineSpine: Bool = false
    @State private var showStatus = false

    private var lesson: Lesson? { store.lesson(for: assignment.lessonID) }
    private var statusTitle: String { assignment.status.readable }

    var body: some View {
        HStack(alignment: .top, spacing: showTimelineSpine ? 12 : 12) {
            if showTimelineSpine {
                timelineSpineRail
            } else {
                quickCheckButton
            }

            cardContentButton
        }
        .padding(showTimelineSpine ? EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0) : EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(showTimelineSpine ? Color.clear : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showStatus) { AssignmentStatusSheet(assignment: assignment) }
    }

    // MARK: - Timeline Spine Rail
    @ViewBuilder
    private var timelineSpineRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : (assignment.status == .completed ? Sage.accent : Sage.accent.opacity(0.35)))
                .frame(width: 3, height: 18)

            quickCheckButton

            Rectangle()
                .fill(isLast ? Color.clear : Sage.accent.opacity(0.35))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 28)
    }

    // MARK: - Quick Check Button
    @ViewBuilder
    private var quickCheckButton: some View {
        Button {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                _ = store.toggleAssignmentStatus(assignment)
            }
        } label: {
            if showTimelineSpine {
                ZStack {
                    if assignment.status == .completed {
                        Circle()
                            .fill(Sage.accent)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else if isActive {
                        Circle()
                            .stroke(Sage.accent, lineWidth: 2.5)
                            .background(Circle().fill(Sage.accent.opacity(0.18)))
                            .frame(width: 26, height: 26)
                        Circle()
                            .fill(Sage.accent)
                            .frame(width: 10, height: 10)
                    } else {
                        Circle()
                            .stroke(Sage.accent.opacity(0.45), lineWidth: 2)
                            .background(Circle().fill(Color(.systemBackground)))
                            .frame(width: 26, height: 26)
                    }
                }
            } else {
                Image(systemName: assignment.status.symbol)
                    .font(.title3)
                    .foregroundStyle(assignment.status == .completed ? Sage.accent : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(assignment.status == .completed ? "Mark incomplete" : "Mark complete")
        .accessibilityIdentifier("toggleStatus-\(lesson?.title ?? "missing")")
    }

    // MARK: - Card Content Button
    @ViewBuilder
    private var cardContentButton: some View {
        Button {
            showStatus = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    let act = LessonActivityType.detect(from: lesson?.title ?? "")
                    HStack(spacing: 4) {
                        Text(act.rawValue).font(.caption)
                        Text(act.name).font(.caption2.weight(.bold)).foregroundStyle(Sage.accent)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Sage.accent.opacity(0.12)))

                    Text([store.student(for: assignment.studentID)?.name, lesson.flatMap(store.course(for:))?.title].compactMap { $0 }.joined(separator: " • "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityHidden(true)

                    Spacer(minLength: 4)

                    Text(statusTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(assignment.status == .completed ? Sage.accent : (isActive ? Color.orange : .secondary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(assignment.status == .completed ? Sage.accent.opacity(0.12) : (isActive ? Color.orange.opacity(0.14) : Color(.tertiarySystemFill)))
                        )
                }

                Text(lesson?.title ?? "Missing lesson")
                    .font(.headline.weight(.bold))
                    .strikethrough(assignment.status == .completed)
                    .foregroundStyle(assignment.status == .completed ? .secondary : .primary)
                    .multilineTextAlignment(.leading)

                if let completedDay = assignment.completedDay {
                    Text("Completed \(SchoolDate.short(completedDay))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isActive ? Sage.accent.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(lesson?.title ?? "Lesson") for \(store.student(for: assignment.studentID)?.name ?? "learner"), \(statusTitle)")
        .accessibilityIdentifier("assignment-\(store.student(for: assignment.studentID)?.name ?? "unknown")-\(lesson?.title ?? "missing")")
    }

    // MARK: - Context Menu Content
    @ViewBuilder
    private var contextMenuContent: some View {
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

    private var currentCourse: Course {
        store.course(for: course.id) ?? course
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
                        Text("\(completedLessonIDs.count) of \(lessons.count) lessons completed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
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

    init(course: Course) {
        self.course = course
        _title = State(initialValue: course.title)
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
            }
            .navigationTitle("Edit Subject")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updateCourse(id: course.id, title: title) {
                            dismiss()
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


private struct SequenceBuilderView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var courseTitle = ""
    @State private var selectedStudents = Set<UUID>()
    @State private var lessonText = ""
    @State private var datesLessons = true
    @State private var startDate = Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]

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
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Build Sequence")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let lessons = lessonText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        if store.addCourse(title: courseTitle, studentIDs: Array(selectedStudents), lessonTitles: lessons, startDay: datesLessons ? SchoolDate.string(startDate) : nil, weekdays: weekdays) { dismiss() }
                    }
                    .disabled(store.state.students.isEmpty)
                    .accessibilityIdentifier("saveCourse")
                }
            }
        }
    }
}


private enum RecordsActiveSheet: Identifiable {
    case attendance
    case activity
    case academicYears
    case export
    case editActivity(LearningActivity)

    var id: String {
        switch self {
        case .attendance: return "attendance"
        case .activity: return "activity"
        case .academicYears: return "academicYears"
        case .export: return "export"
        case .editActivity(let activity): return "editActivity-\(activity.id.uuidString)"
        }
    }
}

struct RecordsView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var selectedYearID: UUID?
    @State private var activeSheet: RecordsActiveSheet?

    private var currentYear: AcademicYear {
        if let selectedYearID, let year = store.academicYear(for: selectedYearID) {
            return year
        }
        return store.activeAcademicYear
    }

    private var scopedAttendance: [AttendanceEntry] {
        store.attendance(in: currentYear)
    }

    private var scopedActivities: [LearningActivity] {
        store.activities(in: currentYear)
    }

    private var totalMinutes: Int { scopedAttendance.reduce(0) { $0 + $1.minutes } }
    private var activityMinutes: Int { scopedActivities.reduce(0) { $0 + $1.minutes } }
    private var totalAttendanceDays: Int { Set(scopedAttendance.map(\.day)).count }
    private var annualTargetDays: Double { Double(currentYear.targetDays) }
    private var complianceProgress: Double {
        guard annualTargetDays > 0 else { return 0 }
        return min(1.0, Double(totalAttendanceDays) / annualTargetDays)
    }

    var body: some View {
        NavigationStack {
            List {
                complianceSection
                reportsSection
                learningRecordsSection
                recentActivitySection
            }
            .navigationTitle("Records")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .export
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportToolbarButton")
                }
                SaveStatusToolbar()
            }
            .sheet(item: $activeSheet) { sheet in
                sheetView(for: sheet)
            }
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: RecordsActiveSheet) -> some View {
        switch sheet {
        case .attendance:
            AttendanceView(year: currentYear)
        case .activity:
            ActivityLogView()
        case .academicYears:
            AcademicYearsView(selectedYearID: $selectedYearID)
        case .export:
            ExportRecordsSheet(initialYear: currentYear)
        case .editActivity(let activity):
            EditActivityView(activity: activity)
        }
    }

    @ViewBuilder
    private var complianceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("ACADEMIC COMPLIANCE")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Sage.accent)

                            academicYearMenu
                        }

                        Text("Annual Learning Chronicle")
                            .font(.title2.weight(.bold))
                        Text("Tracking towards \(currentYear.targetDays) required school days.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color(.tertiarySystemFill), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0.04, complianceProgress)))
                            .stroke(Sage.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(totalAttendanceDays)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Sage.accent)
                            Text("/ \(currentYear.targetDays)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 64, height: 64)
                }

                Divider()

                HStack(spacing: 8) {
                    Metric(title: "Attendance", value: "\(totalAttendanceDays) days")
                    Metric(title: "Confirmed", value: Hours(minutes: totalMinutes))
                    Metric(title: "Activities", value: Hours(minutes: activityMinutes))
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var academicYearMenu: some View {
        Menu {
            ForEach(store.state.academicYears) { year in
                Button {
                    selectedYearID = year.id
                } label: {
                    HStack {
                        Text(year.title)
                        if year.id == currentYear.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button {
                activeSheet = .academicYears
            } label: {
                Label("Manage School Years...", systemImage: "calendar.badge.gearshape")
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentYear.title)
                    .font(.caption.weight(.bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Sage.accent.opacity(0.12), in: Capsule())
            .foregroundStyle(Sage.accent)
        }
        .accessibilityIdentifier("academicYearSelector")
    }

    @ViewBuilder
    private var reportsSection: some View {
        Section("Official reports & exports") {
            Button {
                activeSheet = .export
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .font(.title3)
                        .foregroundStyle(Sage.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export official records")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Printable Letter PDF logs & CSV spreadsheets with legal attestation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("exportOfficialRecords")

            Button {
                activeSheet = .academicYears
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(Sage.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("School years & terms")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(store.state.academicYears.count) school years · Active: \(currentYear.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("manageSchoolYears")
        }
    }

    @ViewBuilder
    private var learningRecordsSection: some View {
        Section("Learning records") {
            Button { activeSheet = .attendance } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Sage.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Attendance & hours")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Daily attendance log and instructional hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("openAttendance")

            Button { activeSheet = .activity } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(Sage.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log retrospective activity")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Field trips, science labs, nature walks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("addActivity")
        }
    }

    @ViewBuilder
    private var recentActivitySection: some View {
        Section("Recent activity (\(currentYear.title))") {
            if scopedActivities.isEmpty && scopedAttendance.isEmpty {
                Text("Confirmed attendance and activities for \(currentYear.title) will appear here.").foregroundStyle(.secondary)
            }
            ForEach(scopedActivities.sorted { $0.day > $1.day }.prefix(12)) { activity in
                HStack(spacing: 12) {
                    Text(activityEmoji(for: activity.title))
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color(.tertiarySystemFill), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.title)
                            .font(.headline.weight(.semibold))
                        Text("\(store.student(for: activity.studentID)?.name ?? "Unknown learner") · \(SchoolDate.short(activity.day)) · \(Hours(minutes: activity.minutes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        _ = store.deleteActivity(id: activity.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteActivity-\(activity.title)")

                    Button {
                        activeSheet = .editActivity(activity)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Sage.accent)
                    .accessibilityIdentifier("editActivity-\(activity.title)")
                }
                .contextMenu {
                    Button {
                        activeSheet = .editActivity(activity)
                    } label: {
                        Label("Edit Activity", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        _ = store.deleteActivity(id: activity.id)
                    } label: {
                        Label("Delete Activity", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func activityEmoji(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("museum") || lower.contains("trip") || lower.contains("tour") { return "🏛️" }
        if lower.contains("nature") || lower.contains("hike") || lower.contains("walk") || lower.contains("park") { return "🌲" }
        if lower.contains("lab") || lower.contains("experiment") || lower.contains("science") { return "🔬" }
        if lower.contains("art") || lower.contains("craft") || lower.contains("draw") { return "🎨" }
        if lower.contains("music") || lower.contains("piano") || lower.contains("sing") { return "🎵" }
        if lower.contains("sport") || lower.contains("swim") || lower.contains("gym") { return "🏃‍♂️" }
        return "⭐"
    }
}

// MARK: - Academic Years Management Views

private struct AcademicYearsView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedYearID: UUID?
    @State private var showAddYear = false
    @State private var editingYear: AcademicYear?
    @State private var yearToDelete: AcademicYear?
    @State private var addingTermForYear: AcademicYear?

    var body: some View {
        NavigationStack {
            List {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Academic Calendars").font(.caption.weight(.bold)).foregroundStyle(Sage.accent)
                        Text("School Years & Terms").font(.largeTitle.bold())
                        Text("Configure annual instructional targets and term pacing to scope legal attendance and reporting.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Defined School Years") {
                    if store.state.academicYears.isEmpty {
                        ContentUnavailableView(
                            "No School Years",
                            systemImage: "calendar.badge.plus",
                            description: Text("Add your academic year to set compliance targets and scope reports.")
                        )
                    } else {
                        ForEach(store.state.academicYears) { year in
                            AcademicYearRowView(
                                year: year,
                                isActive: year.id == store.state.activeYearID,
                                terms: store.terms(for: year.id),
                                onSetActive: {
                                    _ = store.setActiveAcademicYear(id: year.id)
                                    selectedYearID = year.id
                                },
                                onEdit: {
                                    editingYear = year
                                },
                                onAddTerm: {
                                    addingTermForYear = year
                                },
                                onDeleteTerm: { term in
                                    _ = store.deleteTerm(id: term.id)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    yearToDelete = year
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("deleteYear-\(year.title)")

                                Button {
                                    editingYear = year
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Sage.accent)
                                .accessibilityIdentifier("editYear-\(year.title)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("School Years")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddYear = true
                    } label: {
                        Label("Add Year", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addSchoolYearButton")
                }
            }
            .sheet(isPresented: $showAddYear) {
                AddAcademicYearView()
            }
            .sheet(item: $editingYear) { year in
                EditAcademicYearView(year: year)
            }
            .sheet(item: $addingTermForYear) { year in
                AddTermView(year: year)
            }
            .confirmationDialog(
                "Delete School Year?",
                isPresented: Binding(
                    get: { yearToDelete != nil },
                    set: { if !$0 { yearToDelete = nil } }
                ),
                presenting: yearToDelete
            ) { year in
                Button("Delete \(year.title)", role: .destructive) {
                    _ = store.deleteAcademicYear(id: year.id)
                    if selectedYearID == year.id {
                        selectedYearID = store.activeAcademicYear.id
                    }
                    yearToDelete = nil
                }
            } message: { year in
                Text("Deleting \(year.title) will remove its target settings and terms. Existing attendance entries will remain in your records.")
            }
        }
    }
}

private struct AcademicYearRowView: View {
    let year: AcademicYear
    let isActive: Bool
    let terms: [AcademicTerm]
    let onSetActive: () -> Void
    let onEdit: () -> Void
    let onAddTerm: () -> Void
    let onDeleteTerm: (AcademicTerm) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(year.title)
                            .font(.headline.weight(.bold))
                        if isActive {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Sage.accent, in: Capsule())
                        }
                    }

                    Text("\(SchoolDate.short(year.startDay)) – \(SchoolDate.short(year.endDay))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isActive {
                    Button("Set Active", action: onSetActive)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(Sage.accent)
                        .accessibilityIdentifier("setActiveYear-\(year.title)")
                }
            }

            HStack(spacing: 12) {
                Label("\(year.targetDays) Days Target", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let targetHours = year.targetHours {
                    Label("\(targetHours) Hours Target", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !terms.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("TERMS & SEMESTERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    ForEach(terms) { term in
                        HStack {
                            Text(term.title)
                                .font(.footnote.weight(.medium))
                            Spacer()
                            Text("\(SchoolDate.short(term.startDay)) – \(SchoolDate.short(term.endDay))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                onDeleteTerm(term)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("deleteTerm-\(term.title)")
                        }
                    }
                }
            }

            HStack {
                Button(action: onAddTerm) {
                    Label("Add Term", systemImage: "plus.circle")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Sage.accent)
                .accessibilityIdentifier("addTermTo-\(year.title)")

                Spacer()

                Button("Edit Year", action: onEdit)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

private struct AddAcademicYearView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 10, to: Date()) ?? Date()
    @State private var targetDays = 180
    @State private var trackHours = false
    @State private var targetHours = 900
    @State private var makeActive = true

    init() {
        let def = SchoolState.defaultAcademicYear()
        _title = State(initialValue: def.title)
        _startDate = State(initialValue: SchoolDate.date(def.startDay) ?? Date())
        _endDate = State(initialValue: SchoolDate.date(def.endDay) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }

                Section("Year Title") {
                    TextField("e.g. 2024–2025", text: $title)
                        .accessibilityIdentifier("academicYearTitleInput")
                }

                Section("Calendar Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .accessibilityIdentifier("academicYearStartDatePicker")
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .accessibilityIdentifier("academicYearEndDatePicker")
                }

                Section("Compliance Targets") {
                    Stepper("Target School Days: \(targetDays)", value: $targetDays, in: 1...365)
                        .accessibilityIdentifier("academicYearTargetDaysStepper")
                    Toggle("Track Target Hours", isOn: $trackHours)
                        .accessibilityIdentifier("academicYearTrackHoursToggle")
                    if trackHours {
                        Stepper("Target Hours: \(targetHours) hrs", value: $targetHours, in: 1...3000, step: 25)
                            .accessibilityIdentifier("academicYearTargetHoursStepper")
                    }
                }

                Section {
                    Toggle("Set as Active School Year", isOn: $makeActive)
                        .accessibilityIdentifier("academicYearMakeActiveToggle")
                }
            }
            .navigationTitle("Add School Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let startStr = SchoolDate.string(startDate)
                        let endStr = SchoolDate.string(endDate)
                        if store.addAcademicYear(
                            title: title,
                            startDay: startStr,
                            endDay: endStr,
                            targetDays: targetDays,
                            targetHours: trackHours ? targetHours : nil,
                            makeActive: makeActive
                        ) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveSchoolYearButton")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || startDate >= endDate)
                }
            }
        }
    }
}

private struct EditAcademicYearView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let year: AcademicYear
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var targetDays: Int
    @State private var trackHours: Bool
    @State private var targetHours: Int

    init(year: AcademicYear) {
        self.year = year
        _title = State(initialValue: year.title)
        _startDate = State(initialValue: SchoolDate.date(year.startDay) ?? Date())
        _endDate = State(initialValue: SchoolDate.date(year.endDay) ?? Date())
        _targetDays = State(initialValue: year.targetDays)
        _trackHours = State(initialValue: year.targetHours != nil)
        _targetHours = State(initialValue: year.targetHours ?? 900)
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }

                Section("Year Title") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("editAcademicYearTitleInput")
                }

                Section("Calendar Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                Section("Compliance Targets") {
                    Stepper("Target School Days: \(targetDays)", value: $targetDays, in: 1...365)
                    Toggle("Track Target Hours", isOn: $trackHours)
                    if trackHours {
                        Stepper("Target Hours: \(targetHours) hrs", value: $targetHours, in: 1...3000, step: 25)
                    }
                }
            }
            .navigationTitle("Edit School Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let startStr = SchoolDate.string(startDate)
                        let endStr = SchoolDate.string(endDate)
                        if store.updateAcademicYear(
                            id: year.id,
                            title: title,
                            startDay: startStr,
                            endDay: endStr,
                            targetDays: targetDays,
                            targetHours: trackHours ? targetHours : nil
                        ) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveEditSchoolYearButton")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || startDate >= endDate)
                }
            }
        }
    }
}

private struct AddTermView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let year: AcademicYear
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date

    init(year: AcademicYear) {
        self.year = year
        _startDate = State(initialValue: SchoolDate.date(year.startDay) ?? Date())
        _endDate = State(initialValue: SchoolDate.date(year.endDay) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }

                Section("School Year") {
                    LabeledContent("Year", value: year.title)
                }

                Section("Term Details") {
                    TextField("Term Title (e.g. Fall Semester)", text: $title)
                        .accessibilityIdentifier("termTitleInput")
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Term / Semester")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let startStr = SchoolDate.string(startDate)
                        let endStr = SchoolDate.string(endDate)
                        if store.addTerm(yearID: year.id, title: title, startDay: startStr, endDay: endStr) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveTermButton")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || startDate >= endDate)
                }
            }
        }
    }
}

// MARK: - Export Records Sheet

private struct ExportRecordsSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let initialYear: AcademicYear

    @State private var reportType: ReportType = .attendance
    @State private var exportFormat: ExportFormat = .pdf
    @State private var selectedStudentID: UUID? = nil
    @State private var selectedYearID: UUID?

    @State private var exportedFile: ExportedReportFile?
    @State private var exportError: String?

    private var activeYear: AcademicYear {
        if let selectedYearID, let year = store.academicYear(for: selectedYearID) {
            return year
        }
        return initialYear
    }

    private var activeStudent: Student? {
        selectedStudentID.flatMap(store.student(for:))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Report Configuration") {
                    Picker("Report Type", selection: $reportType) {
                        ForEach(ReportType.allCases) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("exportReportTypePicker")

                    Text(reportType.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("School Year", selection: Binding(
                        get: { activeYear.id },
                        set: { selectedYearID = $0 }
                    )) {
                        if store.state.academicYears.isEmpty {
                            Text(initialYear.title).tag(initialYear.id)
                        } else {
                            ForEach(store.state.academicYears) { year in
                                Text(year.title).tag(year.id)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("exportYearPicker")

                    Picker("Learner", selection: $selectedStudentID) {
                        Text("All Learners (Household)").tag(UUID?.none)
                        ForEach(store.state.students) { student in
                            Text(student.name).tag(Optional(student.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("exportStudentPicker")

                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("exportFormatPicker")
                }

                Section("Document Preview") {
                    if let file = exportedFile {
                        if exportFormat == .pdf {
                            #if canImport(PDFKit)
                            PDFKitView(data: file.data)
                                .frame(height: 380)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
                                .accessibilityIdentifier("pdfPreviewView")
                            #else
                            Text("PDF Preview not available on this platform")
                            #endif
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Spreadsheet Ready for Export", systemImage: "tablecells")
                                    .font(.headline)
                                    .foregroundStyle(Sage.accent)
                                Text("RFC 4180 CSV document (\(file.data.count) bytes) compatible with Apple Numbers, Microsoft Excel, and Google Sheets.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    } else if let error = exportError {
                        Text("Generation error: \(error)").foregroundStyle(.red)
                    } else {
                        ProgressView("Preparing preview...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                if let file = exportedFile {
                    Section {
                        ShareLink(
                            item: file.fileURL,
                            preview: SharePreview(file.fileName, icon: Image(systemName: "doc.text.fill"))
                        ) {
                            HStack {
                                Spacer()
                                Label("Share / Save Official Record", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Sage.accent)
                        .accessibilityIdentifier("shareOfficialRecordButton")
                    }
                }
            }
            .navigationTitle("Export Official Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
            .onAppear {
                generateReport()
            }
            .onChange(of: reportType) { generateReport() }
            .onChange(of: exportFormat) { generateReport() }
            .onChange(of: selectedStudentID) { generateReport() }
            .onChange(of: selectedYearID) { generateReport() }
        }
    }

    private func generateReport() {
        let year = activeYear
        let student = activeStudent
        let studentPrefix = student != nil ? "\(student!.name)_" : ""
        let sanitizedYear = year.title.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: " ", with: "_")
        let baseName = "\(studentPrefix)\(reportType.rawValue.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "&", with: "and"))_\(sanitizedYear)"

        do {
            switch exportFormat {
            case .pdf:
                #if canImport(UIKit)
                let pdfData = HomeschoolPDFGenerator.generateReportPDF(
                    type: reportType,
                    state: store.state,
                    student: student,
                    year: year
                )
                let file = try ExportedReportFile(fileName: "\(baseName).pdf", data: pdfData, format: .pdf)
                exportedFile = file
                exportError = nil
                #endif

            case .csv:
                let csvString: String
                switch reportType {
                case .attendance:
                    csvString = HomeschoolCSVGenerator.generateAttendanceCSV(state: store.state, student: student, year: year)
                case .curriculum:
                    csvString = HomeschoolCSVGenerator.generateCurriculumCSV(state: store.state, student: student, year: year)
                case .chronicle:
                    csvString = HomeschoolCSVGenerator.generateChronicleCSV(state: store.state, student: student, year: year)
                }
                let data = Data(csvString.utf8)
                let file = try ExportedReportFile(fileName: "\(baseName).csv", data: data, format: .csv)
                exportedFile = file
                exportError = nil
            }
        } catch {
            exportError = error.localizedDescription
            exportedFile = nil
        }
    }
}

private struct AttendanceView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    var year: AcademicYear? = nil
    @State private var day = Date()
    @State private var studentID: UUID?
    @State private var minutes = 180
    @State private var editingAttendance: AttendanceEntry?

    private var activeYear: AcademicYear { year ?? store.activeAcademicYear }
    private var entries: [AttendanceEntry] { store.attendance(in: activeYear).sorted { $0.day > $1.day } }
    private var totalMinutes: Int { entries.reduce(0) { $0 + $1.minutes } }
    private var recordedDateCount: Int { Set(entries.map(\.day)).count }

    var body: some View {
        NavigationStack {
            List {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Recorded attendance (\(activeYear.title))") {
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
                        let learnerName = store.student(for: entry.studentID)?.name ?? "Unknown learner"
                        LabeledContent("\(learnerName) · \(SchoolDate.short(entry.day))", value: Hours(minutes: entry.minutes))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("attendanceEntry-\(learnerName)-\(entry.day)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    _ = store.deleteAttendance(id: entry.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("deleteAttendance-\(entry.id.uuidString)")

                                Button {
                                    editingAttendance = entry
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Sage.accent)
                                .accessibilityIdentifier("editAttendance-\(entry.id.uuidString)")
                            }
                            .contextMenu {
                                Button {
                                    editingAttendance = entry
                                } label: {
                                    Label("Edit Minutes", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    _ = store.deleteAttendance(id: entry.id)
                                } label: {
                                    Label("Delete Attendance", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Attendance & Hours")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss.callAsFunction) } }
            .sheet(item: $editingAttendance) { entry in
                EditAttendanceView(entry: entry)
            }
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

private struct EditAttendanceView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let entry: AttendanceEntry
    @State private var minutes: Int

    init(entry: AttendanceEntry) {
        self.entry = entry
        _minutes = State(initialValue: entry.minutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                let learnerName = store.student(for: entry.studentID)?.name ?? "Learner"
                Section("\(learnerName) · \(SchoolDate.short(entry.day))") {
                    TextField("Instructional minutes", value: $minutes, format: .number)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("editAttendanceMinutes")
                }
            }
            .navigationTitle("Edit Attendance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updateAttendance(id: entry.id, minutes: minutes) {
                            dismiss()
                        }
                    }
                    .disabled(!(1...1440).contains(minutes))
                    .accessibilityIdentifier("saveEditAttendance")
                }
            }
        }
    }
}

private struct EditActivityView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let activity: LearningActivity
    @State private var title: String
    @State private var day: Date
    @State private var minutes: Int

    init(activity: LearningActivity) {
        self.activity = activity
        _title = State(initialValue: activity.title)
        _day = State(initialValue: SchoolDate.date(activity.day) ?? Date())
        _minutes = State(initialValue: activity.minutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Activity Details") {
                    TextField("What did you learn?", text: $title)
                        .accessibilityIdentifier("editActivityTitle")
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                        .accessibilityIdentifier("editActivityDay")
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...1440)
                        .accessibilityIdentifier("editActivityMinutes")
                }
            }
            .navigationTitle("Edit Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updateActivity(id: activity.id, title: title, day: SchoolDate.string(day), minutes: minutes) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveEditActivity")
                }
            }
        }
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
                        .accessibilityIdentifier("activityStudent-\(student.name)")
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
    @Environment(\.signedInIdentity) private var identity
    @State private var showAccount = false
    @EnvironmentObject private var store: HomeschoolStore
    @State private var showAddStudent = false
    @State private var editingStudent: Student?
    @State private var studentToDelete: Student?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your learning team").font(.caption.weight(.bold)).foregroundStyle(Sage.accent)
                        Text("Family").font(.largeTitle.bold())
                        Text("Manage learner profiles and local settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Learners") {
                    if store.state.students.isEmpty {
                        ContentUnavailableView("No learners yet", systemImage: "person.2.badge.plus", description: Text("Add each learner to start planning independent work."))
                    } else {
                        ForEach(store.state.students) { student in
                            let studentAssignments = store.state.assignments.filter { $0.studentID == student.id }
                            let completed = studentAssignments.filter { $0.status == .completed }.count
                            let attendanceCount = store.state.attendance.filter { $0.studentID == student.id }.count

                            HStack(alignment: .center, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Sage.accent.gradient)
                                        .frame(width: 44, height: 44)
                                    Text(String(student.name.prefix(1)).uppercased())
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(student.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.primary)

                                        Text(student.gradeLevel.isEmpty ? "Grade level not set" : "Grade \(student.gradeLevel)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Sage.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Sage.accent.opacity(0.12)))
                                    }

                                    Text("\(completed) lessons completed · \(attendanceCount) attendance days")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    studentToDelete = student
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("deleteStudent-\(student.name)")

                                Button {
                                    editingStudent = student
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Sage.accent)
                                .accessibilityIdentifier("editStudent-\(student.name)")
                            }
                            .contextMenu {
                                Button {
                                    editingStudent = student
                                } label: {
                                    Label("Edit Learner", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    studentToDelete = student
                                } label: {
                                    Label("Delete Learner", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button("Add Learner", systemImage: "plus") { showAddStudent = true }
                        .font(.headline.weight(.semibold))
                        .accessibilityIdentifier("addStudent")
                }

                Section("Your data & privacy") {
                    if identity != nil {
                        Button("Account & cloud backups") { showAccount = true }
                            .accessibilityIdentifier("openAccount")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("App Settings & Legal", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("openSettingsFromFamily")
                    Label("Saved on this device", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(Sage.accent)
                    Text("Records are saved on this device for your signed-in account. You can create private cloud backups from Account & cloud backups.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showAccount) {
                if let identity { AccountView(identity: identity) }
            }
            .toolbar { SaveStatusToolbar() }
            .sheet(isPresented: $showAddStudent) { AddStudentView() }
            .sheet(item: $editingStudent) { student in
                EditStudentView(student: student)
            }
            .confirmationDialog(
                "Delete Learner?",
                isPresented: Binding(
                    get: { studentToDelete != nil },
                    set: { if !$0 { studentToDelete = nil } }
                ),
                presenting: studentToDelete
            ) { student in
                Button("Delete \(student.name)", role: .destructive) {
                    _ = store.deleteStudent(id: student.id)
                }
                .accessibilityIdentifier("confirmDeleteStudent")
                Button("Cancel", role: .cancel) {
                    studentToDelete = nil
                }
            } message: { student in
                Text("Deleting \(student.name) will permanently remove all of their scheduled assignments, attendance records, and logged activities.")
            }
        }
    }
}

private struct EditStudentView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let student: Student
    @State private var name: String
    @State private var gradeLevel: String

    init(student: Student) {
        self.student = student
        _name = State(initialValue: student.name)
        _gradeLevel = State(initialValue: student.gradeLevel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.presentedError != nil {
                    Section { SaveErrorBanner() }
                }
                Section("Learner details") {
                    TextField("Name", text: $name).accessibilityIdentifier("editStudentName")
                    TextField("Grade level", text: $gradeLevel).accessibilityIdentifier("editStudentGrade")
                }
            }
            .navigationTitle("Edit Learner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updateStudent(id: student.id, name: name, gradeLevel: gradeLevel) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("saveEditStudent")
                }
            }
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
    private var percent: Int { total == 0 ? 0 : Int((Double(completed) / Double(total)) * 100) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DAILY ORBIT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Sage.accent)

                Text("\(completed) of \(total) lessons complete")
                    .font(.title3.weight(.bold))

                if total > 0 {
                    let remaining = total - completed
                    if remaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption.weight(.bold))
                            Text("\(remaining) lesson\(remaining == 1 ? "" : "s") remaining today")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                            Text("All scheduled work complete!")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(Sage.accent)
                    }
                } else {
                    Text("No lessons scheduled yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Preserved for automated accessibility audits and UITest assertions
                ProgressView(value: progress)
                    .tint(Sage.accent)
                    .accessibilityLabel("Family progress")
                    .accessibilityValue("\(completed) of \(total) lessons complete")
            }

            Spacer()

            // Circular Daily Orbit completion gauge
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, progress))))
                    .stroke(
                        Sage.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                VStack(spacing: 0) {
                    Text("\(percent)%")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Sage.accent)
                    Text("Done")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 68, height: 68)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
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
