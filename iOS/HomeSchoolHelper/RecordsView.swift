import SwiftUI
import HomeschoolCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

private enum RecordsActiveSheet: Identifiable {
    case attendance
    case activity
    case academicYears
    case export
    case portfolio
    case readingLog
    case editActivity(LearningActivity)

    var id: String {
        switch self {
        case .attendance: return "attendance"
        case .activity: return "activity"
        case .academicYears: return "academicYears"
        case .export: return "export"
        case .portfolio: return "portfolio"
        case .readingLog: return "readingLog"
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
        case .portfolio:
            PortfolioView()
        case .readingLog:
            ReadingLogView()
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

            Button { activeSheet = .readingLog } label: {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.title3)
                        .foregroundStyle(Sage.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reading log & book list")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(store.state.books.count) books · Currently reading & completed")
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
            .accessibilityIdentifier("openReadingLog")

            Button { activeSheet = .portfolio } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(Sage.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Student work portfolio")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(store.state.portfolioItems.count) work samples · Photos, tests, artwork")
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
            .accessibilityIdentifier("openPortfolio")
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

private struct StatePresetSection: View {
    @Binding var selectedStateCode: String
    @Binding var targetDays: Int
    @Binding var trackHours: Bool
    @Binding var targetHours: Int

    var body: some View {
        Section("State Legal Compliance Preset") {
            Picker("US State Preset", selection: $selectedStateCode) {
                Text("Choose preset to pre-fill...").tag("")
                ForEach(StateCompliancePreset.allStates) { preset in
                    Text("\(preset.name) (\(preset.code))").tag(preset.code)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("academicYearStatePresetPicker")
            .onChange(of: selectedStateCode) { newCode in
                guard !newCode.isEmpty, let preset = StateCompliancePreset.preset(for: newCode) else { return }
                targetDays = preset.defaultDays
                if let hours = preset.defaultHours {
                    trackHours = true
                    targetHours = hours
                }
            }
            if let preset = StateCompliancePreset.preset(for: selectedStateCode) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.name.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Sage.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Sage.accent.opacity(0.12), in: Capsule())
                        Spacer()
                        Text("\(preset.defaultDays) days")
                            .font(.caption.weight(.semibold))
                        if let hrs = preset.defaultHours {
                            Text("• \(hrs) hrs")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    Text(preset.regulatorySummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
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
    @State private var selectedStateCode: String = ""

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

                StatePresetSection(
                    selectedStateCode: $selectedStateCode,
                    targetDays: $targetDays,
                    trackHours: $trackHours,
                    targetHours: $targetHours
                )

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
            .onAppear {
                if selectedStateCode.isEmpty, let defaultState = store.state.selectedStateCode {
                    selectedStateCode = defaultState
                    if let preset = StateCompliancePreset.preset(for: defaultState) {
                        targetDays = preset.defaultDays
                        if let hours = preset.defaultHours {
                            trackHours = true
                            targetHours = hours
                        }
                    }
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
    @State private var selectedStateCode: String = ""

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

                StatePresetSection(
                    selectedStateCode: $selectedStateCode,
                    targetDays: $targetDays,
                    trackHours: $trackHours,
                    targetHours: $targetHours
                )

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

    private var availableFormats: [ExportFormat] {
        if reportType == .calendar {
            return [.ics]
        } else {
            return [.pdf, .csv]
        }
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
                        ForEach(availableFormats) { format in
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
                        } else if exportFormat == .ics {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("iCalendar (.ics) Ready for Export", systemImage: "calendar.badge.clock")
                                    .font(.headline)
                                    .foregroundStyle(Sage.accent)
                                Text("Standard RFC 5545 iCalendar schedule (\(file.data.count) bytes) compatible with Apple Calendar, Google Calendar, and Microsoft Outlook.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
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
            .onChange(of: reportType) {
                if reportType == .calendar {
                    exportFormat = .ics
                } else if exportFormat == .ics {
                    exportFormat = .pdf
                }
                generateReport()
            }
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
            case .ics:
                let icsString = HomeschoolCalendarGenerator.generateICS(
                    state: store.state,
                    studentID: student?.id,
                    academicYear: year
                )
                let data = Data(icsString.utf8)
                let file = try ExportedReportFile(fileName: "\(baseName).ics", data: data, format: .ics)
                exportedFile = file
                exportError = nil

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
                case .curriculum, .calendar:
                    csvString = HomeschoolCSVGenerator.generateCurriculumCSV(state: store.state, student: student, year: year)
                case .chronicle:
                    csvString = HomeschoolCSVGenerator.generateChronicleCSV(state: store.state, student: student, year: year)
                case .transcript:
                    csvString = HomeschoolCSVGenerator.generateTranscriptCSV(state: store.state, student: student, year: year)
                case .readingLog:
                    csvString = HomeschoolCSVGenerator.generateReadingLogCSV(state: store.state, student: student, year: year)
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

