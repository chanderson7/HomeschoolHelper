import SwiftUI
import HomeschoolCore

struct HomeTabView: View {
    @EnvironmentObject private var store: HomeschoolStore

    var body: some View {
        Group {
            if let message = store.loadError {
                LoadFailureView(message: message, retry: store.load)
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
                        EmptyCard(icon: "person.badge.plus", title: "Start with your learners", detail: "Add a child on the Family tab, then build a lesson sequence.")
                    } else {
                        ProgressCard(completed: completedCount, total: displayed.count)
                        HStack {
                            Text("Scheduled work").font(.title2.bold())
                            Spacer()
                            Text("\(displayed.count) scheduled").foregroundStyle(.secondary)
                        }
                        if displayed.isEmpty {
                            EmptyCard(icon: "calendar.badge.checkmark", title: "Nothing scheduled", detail: "Create a dated sequence in Plan, or choose another day.")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(displayed) { assignment in
                                    AssignmentCard(assignment: assignment)
                                }
                            }
                        }

                        HStack {
                            Text("Flexible next work").font(.title2.bold())
                            Spacer()
                            Text("Not dated").foregroundStyle(.secondary)
                        }
                        if flexibleNext.isEmpty {
                            EmptyCard(icon: "list.bullet.rectangle", title: "No flexible work", detail: "Undated lesson sequences will appear here when they are ready to continue.")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(flexibleNext) { assignment in
                                    AssignmentCard(assignment: assignment)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Sage.background.ignoresSafeArea())
            .navigationTitle("Today")
            .toolbar { SaveStatusToolbar() }
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
        Button { showStatus = true } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: assignment.status.symbol)
                    .font(.title3)
                    .foregroundStyle(assignment.status == .completed ? Sage.accent : .secondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson?.title ?? "Missing lesson")
                        .font(.headline)
                        .strikethrough(assignment.status == .completed)
                    Text([store.student(for: assignment.studentID)?.name, lesson.flatMap(store.course(for:))?.title]
                        .compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                    if let completedDay = assignment.completedDay {
                        Text("Completed \(SchoolDate.short(completedDay))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(statusTitle).font(.caption.weight(.semibold)).foregroundStyle(Sage.accent)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
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
    @State private var selectedDay = SchoolDate.today
    @State private var studentID: UUID?
    @State private var showBuilder = false

    private var assignments: [Assignment] {
        store.state.assignments.filter { assignment in
            assignment.scheduledDay == selectedDay && (studentID == nil || assignment.studentID == studentID)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DayPicker(day: $selectedDay).listRowInsets(EdgeInsets())
                    StudentScopePicker(students: store.state.students, selection: $studentID).listRowInsets(EdgeInsets())
                }
                Section("Scheduled work") {
                    if assignments.isEmpty {
                        ContentUnavailableView("No lessons scheduled", systemImage: "calendar.badge.exclamationmark", description: Text("Build a dated sequence or select another day."))
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(assignments) { assignment in
                            AssignmentCard(assignment: assignment)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                Section("Flexible work") {
                    let undated = store.state.assignments.filter { $0.scheduledDay == nil && (studentID == nil || $0.studentID == studentID) }
                    if undated.isEmpty {
                        Text("No flexible lessons.").foregroundStyle(.secondary)
                    } else {
                        ForEach(undated) { assignment in
                            AssignmentCard(assignment: assignment)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle("Your Plan")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Build Sequence", systemImage: "plus") { showBuilder = true }
                        .accessibilityIdentifier("addCourse")
                }
                SaveStatusToolbar()
            }
            .sheet(isPresented: $showBuilder) { SequenceBuilderView() }
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
            .onChange(of: studentID) { _ in prefillMinutes() }
            .onChange(of: day) { _ in prefillMinutes() }
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
    let students: [Student]
    @Binding var selection: UUID?

    var body: some View {
        Menu {
            Button("All learners") { selection = nil }
            ForEach(students) { student in Button(student.name) { selection = student.id } }
        } label: {
            Label(selection.flatMap { id in students.first { $0.id == id }?.name } ?? "All learners", systemImage: "person.2")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Learner filter")
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
