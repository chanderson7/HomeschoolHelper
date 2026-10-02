import SwiftUI
import HomeschoolCore
#if canImport(PhotosUI)
import PhotosUI
#endif

struct TodayView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var studentID: UUID?
    @State private var selectedDay = SchoolDate.today
    @State private var showNewStudent = false
    @State private var showNewCourse = false
    @State private var showPacedReschedule = false
    @State private var showAutoRebalance = false
    @State private var animateArt = false
    @State private var sunGlowPulse = false

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
                    // Botanical Morning Header
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

                        // Watercolor eucalyptus & morning sun art
                        Image("TodayHeroArt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 85)
                            .offset(x: 10, y: -10)
                            .scaleEffect(animateArt ? 1.0 : 0.92)
                            .opacity(animateArt ? 1.0 : 0.0)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: "sun.max.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.orange.opacity(0.85))
                                Text(SchoolDate.long(selectedDay))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text("A little learning.\nA lovely day.")
                                .font(.system(.largeTitle, design: .serif, weight: .bold))
                                .foregroundStyle(.primary)
                                .accessibilityAddTraits(.isHeader)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 95)
                    }
                    .padding(.top, 4)

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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAutoRebalance = true
                    } label: {
                        Label("Rebalance", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("todayRebalanceButton")
                }
            }
            .sheet(isPresented: $showNewStudent) { AddStudentView() }
            .sheet(isPresented: $showNewCourse) { SequenceBuilderView() }
            .sheet(isPresented: $showPacedReschedule) { SmartPacedRescheduleSheet(studentID: studentID) }
            .sheet(isPresented: $showAutoRebalance) { ScheduleRebalanceSheet(initialStudentID: studentID) }
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
            OverdueCatchUpCard(
                overdueCount: overdue.count,
                onCatchUp: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        _ = store.rescheduleOverdue(to: SchoolDate.today, studentID: studentID)
                    }
                },
                onPacedPush: {
                    showAutoRebalance = true
                }
            )
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
    let onPacedPush: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(overdueCount) Past Lesson\(overdueCount == 1 ? "" : "s") Unfinished")
                        .font(.headline.weight(.bold))
                    Text("Choose how you'd like to reschedule:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onPacedPush) {
                    Label("Smart Pacing", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Sage.accent)
                .accessibilityIdentifier("pacedCatchUpButton")

                Button("Move to Today", action: onCatchUp)
                    .font(.subheadline.bold())
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .accessibilityIdentifier("catchUpOverdue")
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct SmartPacedRescheduleSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let studentID: UUID?
    @State private var startDay = SchoolDate.today
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var rescheduleResult: PacedRescheduleResult?

    private var overdueAssignments: [Assignment] {
        store.overdueAssignments(asOf: SchoolDate.today, studentID: studentID)
    }

    private var overdueCount: Int {
        overdueAssignments.count
    }

    private struct OverdueCourseItem: Identifiable {
        let id: UUID
        let name: String
        let count: Int
    }

    private var overdueCoursesSummary: [OverdueCourseItem] {
        let overdue = overdueAssignments
        let lessonMap = Dictionary(uniqueKeysWithValues: store.state.lessons.map { ($0.id, $0) })
        var counts: [UUID: Int] = [:]
        for a in overdue {
            if let courseID = lessonMap[a.lessonID]?.courseID {
                counts[courseID, default: 0] += 1
            }
        }
        var items: [OverdueCourseItem] = []
        for (courseID, count) in counts {
            if let course = store.state.courses.first(where: { $0.id == courseID }) {
                items.append(OverdueCourseItem(id: courseID, name: course.title, count: count))
            }
        }
        items.sort { $0.name < $1.name }
        return items
    }

    private var maxOverdueInAnyCourse: Int {
        overdueCoursesSummary.map(\.count).max() ?? 0
    }

    /// Cannot select more school days than classes to make up
    private var maxDaysAllowed: Int {
        max(1, min(overdueCount, 7))
    }

    /// Minimum days needed so courses with multiple overdue lessons don't double up
    private var minDaysNeeded: Int {
        max(1, min(maxOverdueInAnyCourse, maxDaysAllowed))
    }

    private let weekdayOptions = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    private var activeDaysDescription: String {
        let names = weekdayOptions
            .filter { weekdays.contains($0.0) }
            .map { $0.1 }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }

    private func clampWeekdaysToAllowed() {
        guard overdueCount > 0 else { return }
        if weekdays.count > maxDaysAllowed {
            let standardOrder = [2, 3, 4, 5, 6, 7, 1]
            let existingInOrder = standardOrder.filter { weekdays.contains($0) }
            weekdays = Set(existingInOrder.prefix(maxDaysAllowed))
        } else if weekdays.count < minDaysNeeded {
            let standardOrder = [2, 3, 4, 5, 6, 7, 1]
            var current = weekdays
            for day in standardOrder {
                if current.count >= minDaysNeeded { break }
                current.insert(day)
            }
            weekdays = current
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = rescheduleResult {
                    confirmationView(result: result)
                } else {
                    rescheduleForm
                }
            }
            .navigationTitle(rescheduleResult == nil ? "Smart Reschedule" : "Reschedule Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(rescheduleResult == nil ? "Cancel" : "Done", action: dismiss.callAsFunction)
                }
            }
            .onAppear {
                clampWeekdaysToAllowed()
            }
        }
    }

    private var rescheduleForm: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("How Smart Pacing Works", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Sage.accent)
                    Text("Overdue lessons from past dates are moved forward sequentially starting on your chosen start date across active school days. Each subject gets at most one lesson per day so your student stays on track without feeling overwhelmed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Pacing Options") {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { SchoolDate.date(startDay) ?? Date() },
                        set: {
                            startDay = SchoolDate.string($0)
                            clampWeekdaysToAllowed()
                        }
                    ),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("pacedStartDatePicker")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Active School Days")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if overdueCount > 0 {
                            Text("\(weekdays.count) of \(maxDaysAllowed) selected")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(weekdays.count == maxDaysAllowed ? Sage.accent : .secondary)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
                        ForEach(weekdayOptions, id: \.0) { option in
                            let isSelected = weekdays.contains(option.0)
                            let canSelect = isSelected || weekdays.count < maxDaysAllowed
                            Button(option.1) {
                                if isSelected {
                                    if weekdays.count > minDaysNeeded {
                                        weekdays.remove(option.0)
                                    }
                                } else {
                                    if weekdays.count < maxDaysAllowed {
                                        weekdays.insert(option.0)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(isSelected ? Sage.accent : .gray)
                            .disabled(!canSelect)
                            .opacity(!canSelect ? 0.35 : 1.0)
                            .accessibilityLabel("\(option.1) pacing day")
                        }
                    }

                    if overdueCount > 0 {
                        if weekdays.count == maxDaysAllowed && maxDaysAllowed < 7 {
                            Text("Selected all \(maxDaysAllowed) allowed \(maxDaysAllowed == 1 ? "day" : "days") for your \(overdueCount) overdue \(overdueCount == 1 ? "class" : "classes"). Deselect a day to choose another.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if minDaysNeeded > 1 && weekdays.count == minDaysNeeded {
                            Text("A subject has \(minDaysNeeded) overdue lessons, requiring at least \(minDaysNeeded) school days so lessons don't double up.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Choose up to \(maxDaysAllowed) \(maxDaysAllowed == 1 ? "school day" : "school days") to spread out your \(overdueCount) overdue \(overdueCount == 1 ? "class" : "classes").")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Overdue Lessons to Reschedule") {
                LabeledContent("Total Overdue Lessons", value: "\(overdueCount)")
                    .font(.body.weight(.medium))

                if overdueCoursesSummary.isEmpty {
                    Text("No overdue lessons found for this learner.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(overdueCoursesSummary) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.count) \(item.count == 1 ? "lesson" : "lessons")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    applyPacedReschedule()
                } label: {
                    HStack {
                        Spacer()
                        Label("Apply Smart Pacing", systemImage: "calendar.badge.clock")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Sage.accent)
                .disabled(overdueCount == 0 || weekdays.isEmpty)
                .accessibilityIdentifier("confirmSmartPacedRescheduleButton")
            } footer: {
                if overdueCount > 0 && !weekdays.isEmpty {
                    Text("Lessons will be distributed starting \(SchoolDate.short(startDay)) on \(activeDaysDescription).")
                }
            }
        }
    }

    @ViewBuilder
    private func confirmationView(result: PacedRescheduleResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Sage.accent.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Sage.accent)
                }
                .padding(.top, 24)

                VStack(spacing: 8) {
                    Text("Smart Pacing Applied!")
                        .font(.title2.weight(.bold))
                    Text("Overdue lessons have been placed across your chosen make-up days. Upcoming lessons were smoothly shifted forward so your student doesn't double up on any subject.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(spacing: 12) {
                    HStack {
                        Label("Overdue Lessons Caught Up", systemImage: "checkmark.circle.fill")
                        Spacer()
                        let caughtUp = result.overdueRescheduledCount > 0 ? result.overdueRescheduledCount : result.rescheduledCount
                        Text("\(caughtUp)")
                            .font(.headline)
                            .foregroundStyle(Sage.accent)
                    }
                    if result.futureShiftedCount > 0 {
                        Divider()
                        HStack {
                            Label("Upcoming Lessons Adjusted", systemImage: "arrow.forward.circle")
                            Spacer()
                            Text("\(result.futureShiftedCount) shifted forward")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    HStack {
                        Label("Subjects Balanced", systemImage: "square.stack.3d.up")
                        Spacer()
                        Text("\(result.affectedCoursesCount)")
                            .font(.headline)
                    }
                    Divider()
                    HStack {
                        Label("Starting From", systemImage: "calendar")
                        Spacer()
                        Text(SchoolDate.short(startDay))
                            .font(.subheadline.weight(.medium))
                    }
                    Divider()
                    HStack {
                        Label("Scheduled Days", systemImage: "clock")
                        Spacer()
                        Text(activeDaysDescription)
                            .font(.subheadline.weight(.medium))
                    }
                    if let newDay = result.newCompletionDay {
                        Divider()
                        HStack {
                            Label("Projected Finish", systemImage: "flag.checkered")
                            Spacer()
                            Text(SchoolDate.short(newDay))
                                .font(.headline)
                                .foregroundStyle(Sage.accent)
                        }
                    }
                }
                .padding()
                .background(Sage.soft)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Sage.accent.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Label("What happens next?", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                    Text("Your daily agenda on Today and your curriculum calendar in Plan now reflect your balanced schedule. Lessons will appear on each assigned date.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Sage.accent)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier("dismissSmartPacedConfirmationButton")
            }
            .padding(.bottom, 32)
        }
        .background(Sage.background.ignoresSafeArea())
    }

    private func applyPacedReschedule() {
        if let result = store.rescheduleOverduePaced(
            from: startDay,
            studentID: studentID,
            weekdays: weekdays
        ) {
            withAnimation(.easeInOut) {
                rescheduleResult = result
            }
        }
    }
}

private struct TodayAttendanceCard: View {
    @EnvironmentObject private var store: HomeschoolStore
    let studentID: UUID?
    let selectedDay: String
    @State private var selectedHours: Int = 4
    @State private var selectedMinutes: Int = 0
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

    private var totalMinutes: Int {
        (selectedHours * 60) + selectedMinutes
    }

    private var formattedDuration: String {
        let h = Double(totalMinutes) / 60.0
        return "\(String(format: "%.1f", h)) hrs (\(totalMinutes)m)"
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
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wrap Up Today's School")
                                .font(.headline.weight(.bold))
                            Text("Confirm attendance for \(unrecordedStudents.map(\.name).joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(Sage.accent)
                            Text(formattedDuration)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Sage.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Sage.accent.opacity(0.12), in: Capsule())
                    }

                    // Scroll Wheel GUI
                    HStack(spacing: 0) {
                        Picker("Hours", selection: $selectedHours) {
                            ForEach(0...12, id: \.self) { h in
                                Text("\(h) \(h == 1 ? "hr" : "hrs")").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 105)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        guard totalMinutes > 0 else { return }
                        for student in unrecordedStudents {
                            _ = store.confirmAttendance(studentID: student.id, day: selectedDay, minutes: totalMinutes)
                        }
                        withAnimation {
                            justConfirmed = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Attendance (\(formattedDuration))")
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(totalMinutes > 0 ? Sage.accent : Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(totalMinutes == 0)
                    .accessibilityIdentifier("quickConfirmAttendance")
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

struct AssignmentCard: View {
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
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: assignment.status == .completed)

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
                            .symbolEffect(.bounce, value: assignment.status == .completed)
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
        .buttonStyle(SpringScaleButtonStyle())
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

struct AssignmentStatusSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    let assignment: Assignment
    @State private var status: AssignmentStatus
    @State private var completionDate: Date
    @State private var gradeString: String
    @State private var notes: String
    @State private var categoryID: UUID?
    @State private var showingAddPortfolioSampleSheet = false

    init(assignment: Assignment) {
        self.assignment = assignment
        _status = State(initialValue: assignment.status)
        _completionDate = State(initialValue: SchoolDate.date(assignment.completedDay) ?? Date())
        _gradeString = State(initialValue: assignment.grade.map { String(format: "%g", $0) } ?? "")
        _notes = State(initialValue: assignment.notes ?? "")
        _categoryID = State(initialValue: assignment.categoryID)
    }

    private var previewLetterGrade: String? {
        guard let g = Double(gradeString.trimmingCharacters(in: .whitespacesAndNewlines)), (0...100).contains(g) else { return nil }
        switch g {
        case 93...: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
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
                        Text("Completing a lesson marks it done for this learner.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Academic Evaluation (Optional)") {
                    HStack {
                        Text("Score / Grade")
                        Spacer()
                        TextField("0 - 100", text: $gradeString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                            .accessibilityIdentifier("assignmentGradeField")
                        if !gradeString.isEmpty {
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                        if let preview = previewLetterGrade {
                            Text("(\(preview))")
                                .font(.headline)
                                .foregroundStyle(Sage.accent)
                        }
                    }

                    let courseCategories = store.lesson(for: assignment.lessonID).flatMap { store.course(for: $0) }.map { store.gradeCategories(for: $0.id) } ?? []
                    if !courseCategories.isEmpty {
                        Picker("Category", selection: $categoryID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(courseCategories) { cat in
                                Text(cat.name).tag(cat.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    TextField("Teacher notes or feedback", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("assignmentNotesField")
                }

                Section("Work Portfolio") {
                    let samples = store.state.portfolioItems.filter { $0.assignmentID == assignment.id }
                    if !samples.isEmpty {
                        Text("\(samples.count) work sample\(samples.count == 1 ? "" : "s") attached to this lesson")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        showingAddPortfolioSampleSheet = true
                    } label: {
                        Label(samples.isEmpty ? "Attach Work Sample Photo" : "Attach Another Sample", systemImage: "camera")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Sage.accent)
                    }
                    .accessibilityIdentifier("attachWorkSampleButton")
                }
            }
            .navigationTitle("Update Lesson")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.setStatus(assignment, status: status, completedDay: status == .completed ? SchoolDate.string(completionDate) : nil) {
                            let trimmedGrade = gradeString.trimmingCharacters(in: .whitespacesAndNewlines)
                            let parsedGrade = trimmedGrade.isEmpty ? nil : Double(trimmedGrade)
                            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            let cleanNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

                            if !trimmedGrade.isEmpty && parsedGrade == nil {
                                store.presentedError = AppMessage(title: "Invalid Grade", message: "Grade must be a valid number between 0 and 100.")
                                return
                            }
                            _ = store.setAssignmentCategory(id: assignment.id, categoryID: categoryID)
                            if store.setAssignmentGrade(id: assignment.id, grade: parsedGrade, notes: cleanNotes) {
                                dismiss()
                            }
                        }
                    }
                    .accessibilityIdentifier("saveAssignmentStatus")
                }
            }
            .sheet(isPresented: $showingAddPortfolioSampleSheet) {
                let lesson = store.lesson(for: assignment.lessonID)
                let course = lesson.flatMap { store.course(for: $0) }
                let sampleTitle = [course?.title, lesson?.title].compactMap { $0 }.joined(separator: " - ")

                AddPortfolioItemSheet(
                    initialStudentID: assignment.studentID,
                    initialCourseID: course?.id,
                    initialAssignmentID: assignment.id,
                    initialTitle: sampleTitle.isEmpty ? nil : sampleTitle
                )
            }
        }
    }
}
