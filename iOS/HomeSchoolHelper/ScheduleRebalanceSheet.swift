import SwiftUI
import HomeschoolCore

public struct ScheduleRebalanceSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedStudentID: UUID?
    @State private var selectedCourseID: UUID?
    @State private var strategy: ScheduleRebalanceStrategy = .pushByDays
    @State private var startDate: Date = Date()
    @State private var pushDaysCount: Int = 3
    @State private var breakEndDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var targetFinishDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var showPaywall: Bool = false
    @State private var rebalanceResult: ScheduleRebalanceResult?

    private let weekdayOptions: [(Int, String)] = [
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat"),
        (1, "Sun")
    ]

    public init(initialStudentID: UUID? = nil, initialCourseID: UUID? = nil) {
        _selectedStudentID = State(initialValue: initialStudentID)
        _selectedCourseID = State(initialValue: initialCourseID)
    }

    private var availableCourses: [Course] {
        if let selectedStudentID {
            let courseIDs = Set(store.state.assignments.filter { $0.studentID == selectedStudentID }.compactMap { store.lesson(for: $0.lessonID)?.courseID })
            return store.state.courses.filter { courseIDs.contains($0.id) }
        }
        return store.state.courses
    }

    private var targetScopeAssignments: [Assignment] {
        let lessonMap = Dictionary(uniqueKeysWithValues: store.state.lessons.map { ($0.id, $0) })
        return store.state.assignments.filter { a in
            if let selectedStudentID, a.studentID != selectedStudentID { return false }
            if let selectedCourseID, let lesson = lessonMap[a.lessonID], lesson.courseID != selectedCourseID { return false }
            return a.status != .completed && a.status != .skipped && a.scheduledDay != nil
        }
    }

    private var currentProjectedFinish: String? {
        targetScopeAssignments.compactMap(\.scheduledDay).max()
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let result = rebalanceResult {
                    successSummaryView(result: result)
                } else {
                    rebalanceFormView
                }
            }
            .navigationTitle(rebalanceResult == nil ? "Auto-Rebalance Schedule" : "Schedule Rebalanced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(rebalanceResult == nil ? "Cancel" : "Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("rebalanceDismissButton")
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var rebalanceFormView: some View {
        Form {
            // Header Explanation Card
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Sage.accent)
                        Text("\"Life Happens\" Auto-Rebalance")
                            .font(.headline)
                            .foregroundStyle(Sage.accent)
                    }
                    Text("Sick days, travel, or slow weeks? Automatically ripple uncompleted lessons forward while strictly honoring your 4-day or 5-day school week.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Target Scope
            Section("Rebalance Scope") {
                Picker("Learner", selection: $selectedStudentID) {
                    Text("All Learners").tag(nil as UUID?)
                    ForEach(store.state.students) { student in
                        Text(student.name).tag(student.id as UUID?)
                    }
                }
                .accessibilityIdentifier("rebalanceStudentPicker")

                Picker("Subject", selection: $selectedCourseID) {
                    Text("All Subjects").tag(nil as UUID?)
                    ForEach(availableCourses) { course in
                        Text(course.title).tag(course.id as UUID?)
                    }
                }
                .accessibilityIdentifier("rebalanceCoursePicker")
            }

            // Strategy Picker
            Section("Rebalancing Strategy") {
                Picker("Strategy", selection: $strategy) {
                    Text("⚡️ Push Forward").tag(ScheduleRebalanceStrategy.pushByDays)
                    Text("☀️ Resume Today").tag(ScheduleRebalanceStrategy.resumeToday)
                    Text("🏖 Skip Vacation").tag(ScheduleRebalanceStrategy.skipBreak)
                    Text("🎯 Target End Date").tag(ScheduleRebalanceStrategy.distributeToEndDate)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("rebalanceStrategyPicker")

                strategyConfigSection
            }

            // School Week Cadence
            Section("Active School Days") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Weekly Rhythm")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button("Mon–Fri (5-Day)") {
                            weekdays = [2, 3, 4, 5, 6]
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Sage.accent)

                        Text("•").foregroundStyle(.secondary)

                        Button("Mon–Thu (4-Day)") {
                            weekdays = [2, 3, 4, 5]
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(weekdayOptions, id: \.0) { option in
                            Button(option.1) {
                                if weekdays.contains(option.0) {
                                    if weekdays.count > 1 { weekdays.remove(option.0) }
                                } else {
                                    weekdays.insert(option.0)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(weekdays.contains(option.0) ? Sage.accent : .gray)
                            .accessibilityLabel("\(option.1) active school day")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Live Impact Preview Card
            Section("Impact Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Scope Lessons", systemImage: "books.vertical.fill")
                        Spacer()
                        Text("\(targetScopeAssignments.count) uncompleted")
                            .font(.subheadline.weight(.semibold))
                    }
                    if let finish = currentProjectedFinish {
                        HStack {
                            Label("Current Finish", systemImage: "flag.checkered")
                            Spacer()
                            Text(formatDay(finish))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.footnote)
            }

            // Action Button
            Section {
                Button {
                    executeRebalance()
                } label: {
                    HStack {
                        Spacer()
                        if !subscriptionManager.isPro {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                        }
                        Text(subscriptionManager.isPro ? "Apply Auto-Rebalance" : "Unlock Auto-Rebalance with Pro")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Sage.accent)
                .accessibilityIdentifier("applyRebalanceButton")
            } footer: {
                if !subscriptionManager.isPro {
                    Text("Auto-Rebalance is an EZHomeschool Pro feature. 7-day free trial available.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var strategyConfigSection: some View {
        switch strategy {
        case .pushByDays:
            DatePicker("Start From", selection: $startDate, displayedComponents: .date)
                .accessibilityIdentifier("rebalanceStartDatePicker")
            Stepper(value: $pushDaysCount, in: 1...30) {
                HStack {
                    Text("Push Forward by")
                    Spacer()
                    Text("\(pushDaysCount) school day\(pushDaysCount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                }
            }
            .accessibilityIdentifier("rebalanceDaysStepper")
            Text("Advances all lessons on or after this date by \(pushDaysCount) active school days, skipping weekends and off-days.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .resumeToday:
            DatePicker("Resume Date", selection: $startDate, displayedComponents: .date)
                .accessibilityIdentifier("rebalanceStartDatePicker")
            Text("Lays out all remaining uncompleted lessons in sequence starting on this date, clearing all overdue backlog.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .skipBreak:
            DatePicker("Vacation Start", selection: $startDate, displayedComponents: .date)
                .accessibilityIdentifier("rebalanceBreakStartDatePicker")
            DatePicker("Vacation End", selection: $breakEndDate, displayedComponents: .date)
                .accessibilityIdentifier("rebalanceBreakEndDatePicker")
            Text("Pauses learning during this break window and automatically resumes remaining lessons on the next school day.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .distributeToEndDate:
            DatePicker("Start From", selection: $startDate, displayedComponents: .date)
                .accessibilityIdentifier("rebalanceStartDatePicker")
            DatePicker("Target Graduation", selection: $targetFinishDate, displayedComponents: .date)
                .accessibilityIdentifier("rebalanceTargetEndDatePicker")
            Text("Evenly paces remaining lessons across all active school days until your target end date.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func successSummaryView(result: ScheduleRebalanceResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celebration Badge
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Sage.soft)
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Sage.accent)
                    }
                    Text("Schedule Successfully Rebalanced!")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Your family's calendar is updated and aligned with your school rhythm.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)

                // Key Stat Badges
                HStack(spacing: 16) {
                    statCard(
                        title: "Rescheduled",
                        value: "\(result.rescheduledCount)",
                        icon: "calendar.badge.clock",
                        color: .blue
                    )
                    statCard(
                        title: "Subjects",
                        value: "\(result.affectedCoursesCount)",
                        icon: "books.vertical.fill",
                        color: Sage.accent
                    )
                }
                .padding(.horizontal)

                // Date shift comparison
                if let prev = result.previousFinishDay, let next = result.newFinishDay {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Projected Finish Shift")
                            .font(.headline)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Previous")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatDay(prev))
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.headline)
                                .foregroundStyle(Sage.accent)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("New Projected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatDay(next))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Sage.accent)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Course Breakdown List
                if !result.courseDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subject Breakdown")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 1) {
                            ForEach(result.courseDetails) { detail in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(detail.courseTitle)
                                            .font(.subheadline.weight(.medium))
                                        if let endDay = detail.newProjectedEndDay {
                                            Text("Finish: \(formatDay(endDay))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(detail.rescheduledLessonCount) moved")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Sage.soft, in: Capsule())
                                        .foregroundStyle(Sage.accent)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Sage.accent)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .accessibilityIdentifier("rebalanceDoneConfirmationButton")
            }
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func executeRebalance() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        if !subscriptionManager.isPro {
            showPaywall = true
            return
        }

        let startDayString = SchoolDate.string(startDate)
        let breakEndDayString = strategy == .skipBreak ? SchoolDate.string(breakEndDate) : nil
        let targetFinishDayString = strategy == .distributeToEndDate ? SchoolDate.string(targetFinishDate) : nil

        let request = ScheduleRebalanceRequest(
            studentID: selectedStudentID,
            courseID: selectedCourseID,
            strategy: strategy,
            startDay: startDayString,
            pushDaysCount: pushDaysCount,
            breakEndDay: breakEndDayString,
            targetFinishDay: targetFinishDayString,
            weekdays: weekdays
        )

        if let res = store.rebalanceSchedule(request) {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                rebalanceResult = res
            }
        }
    }

    private func formatDay(_ day: String) -> String {
        guard let date = SchoolDate.date(day) else { return day }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
