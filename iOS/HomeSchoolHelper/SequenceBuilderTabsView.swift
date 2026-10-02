import SwiftUI
import HomeschoolCore

public enum SequenceBuilderStep: Int, CaseIterable, Identifiable {
    case starter = 0
    case schedule = 1
    case lessons = 2
    case learners = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .starter: return "Starter"
        case .schedule: return "Schedule"
        case .lessons: return "Lessons"
        case .learners: return "Learners"
        }
    }

    public var icon: String {
        switch self {
        case .starter: return "sparkles"
        case .schedule: return "calendar"
        case .lessons: return "calendar.badge.clock"
        case .learners: return "person.2.fill"
        }
    }
}

public enum LessonViewMode: String, CaseIterable, Identifiable {
    case calendar = "Calendar Preview"
    case list = "List Editor"

    public var id: String { rawValue }
}

public struct GradeCategoryDraft: Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var weight: Double

    public init(id: UUID = UUID(), name: String, weight: Double) {
        self.id = id
        self.name = name
        self.weight = weight
    }
}

public enum GradeCategoryPreset: String, CaseIterable, Identifiable {
    case equal = "Equal Weighting (Default)"
    case highSchoolCore = "High School Core (50/30/20)"
    case stemScience = "STEM & Labs (40/35/25)"
    case elementary = "Elementary / Practice (30/30/40)"
    case custom = "Custom Categories"

    public var id: String { rawValue }

    public var summary: String {
        switch self {
        case .equal:
            return "All assignments count equally toward the final course grade."
        case .highSchoolCore:
            return "Tests & Exams (50%) • Quizzes (30%) • Homework & Daily (20%)"
        case .stemScience:
            return "Unit Exams (40%) • Labs & Projects (35%) • Daily Assignments (25%)"
        case .elementary:
            return "Assessments (30%) • Quizzes (30%) • Classwork & Practice (40%)"
        case .custom:
            return "Define custom categories and percentage weights."
        }
    }

    public var defaultCategories: [GradeCategoryDraft] {
        switch self {
        case .equal:
            return []
        case .highSchoolCore:
            return [
                GradeCategoryDraft(name: "Tests & Exams", weight: 0.50),
                GradeCategoryDraft(name: "Quizzes", weight: 0.30),
                GradeCategoryDraft(name: "Homework & Daily", weight: 0.20)
            ]
        case .stemScience:
            return [
                GradeCategoryDraft(name: "Unit Exams", weight: 0.40),
                GradeCategoryDraft(name: "Labs & Projects", weight: 0.35),
                GradeCategoryDraft(name: "Daily Assignments", weight: 0.25)
            ]
        case .elementary:
            return [
                GradeCategoryDraft(name: "Assessments", weight: 0.30),
                GradeCategoryDraft(name: "Quizzes", weight: 0.30),
                GradeCategoryDraft(name: "Classwork & Practice", weight: 0.40)
            ]
        case .custom:
            return [
                GradeCategoryDraft(name: "Tests", weight: 0.50),
                GradeCategoryDraft(name: "Assignments", weight: 0.50)
            ]
        }
    }
}

public struct SequenceBuilderTabsView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: SequenceBuilderStep = .starter

    // Course state
    @State private var courseTitle = ""
    @State private var selectedStudents = Set<UUID>()
    @State private var lessonDrafts: [LessonDraft] = [LessonDraft(title: "Lesson 1")]
    @State private var datesLessons = true
    @State private var startDate = Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var hasCredits = false
    @State private var creditHours: Double = 1.0
    @State private var weight: Double = 4.0

    // Grading & Category state
    @State private var categoryPreset: GradeCategoryPreset = .equal
    @State private var categoryDrafts: [GradeCategoryDraft] = []

    // Template & Preset state
    @State private var selectedCategory: CurriculumSubjectCategory = .all
    @State private var activePresetID: String? = nil
    @State private var selectedTemplate: CurriculumTemplateType = .blank
    @State private var chapterPrefix = "Chapter"
    @State private var chapterCount = 30
    @State private var pasteBuffer = ""
    @State private var isShowingAllLessons = false
    @State private var appliedToast: String? = nil

    // Calendar Preview state
    @State private var lessonViewMode: LessonViewMode = .calendar
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    private let weekdayNames = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
    private let calendarHeaderDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let suggestedSubjects = ["Math", "Language Arts", "Science", "History", "Bible", "Art", "Music", "Foreign Language", "Physical Ed"]

    public init() {}

    private var lessonTitles: [String] {
        lessonDrafts.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var scheduledPreviews: [ScheduledLessonPreview] {
        LessonPlanTemplateEngine.previewSchedule(
            titles: lessonTitles,
            startDate: startDate,
            weekdays: weekdays,
            datesLessons: datesLessons
        )
    }

    private var estimatedFinishDateString: String {
        scheduledPreviews.last?.formattedDateString ?? "Flexible"
    }

    private var totalWeeksCount: Int {
        guard !weekdays.isEmpty else { return 0 }
        return Int(ceil(Double(lessonTitles.count) / Double(weekdays.count)))
    }

    private var totalCategoryWeight: Double {
        categoryDrafts.reduce(0) { $0 + $1.weight }
    }

    private var canCreateCourse: Bool {
        !courseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedStudents.isEmpty &&
        !lessonDrafts.isEmpty &&
        lessonTitles.allSatisfy { !$0.isEmpty } &&
        (categoryPreset == .equal || totalCategoryWeight <= 1.001)
    }

    private var displayedDraftIndices: [Int] {
        if lessonDrafts.count > 40 && !isShowingAllLessons {
            return Array(0..<min(25, lessonDrafts.count))
        }
        return Array(lessonDrafts.indices)
    }

    private var assignedStudentNames: String {
        let names = store.state.students.filter { selectedStudents.contains($0.id) }.map { $0.name }
        return names.isEmpty ? "None selected" : names.joined(separator: ", ")
    }

    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var filteredPresets: [CurriculumPreset] {
        if selectedCategory == .all {
            return CurriculumPreset.catalog
        } else {
            return CurriculumPreset.catalog.filter { $0.category == selectedCategory }
        }
    }

    private var filteredItemCount: Int {
        if selectedCategory == .all {
            return CurriculumPreset.catalog.count + CurriculumTemplateType.allCases.count
        } else if selectedCategory == .custom {
            return CurriculumTemplateType.allCases.count
        } else {
            return filteredPresets.count
        }
    }

    private var sectionHeaderTitle: String {
        switch selectedCategory {
        case .all: return "CURRICULUM PRESETS & TOOLS"
        case .math: return "POPULAR MATH PRESETS"
        case .history: return "HISTORY & SOCIAL STUDIES PRESETS"
        case .science: return "SCIENCE & NATURE STUDY PRESETS"
        case .languageArts: return "LANGUAGE ARTS & LITERATURE PRESETS"
        case .electives: return "ELECTIVES & FAITH PRESETS"
        case .custom: return "CUSTOM RHYTHMS & IMPORT TOOLS"
        }
    }

    private func applyPreset(_ preset: CurriculumPreset) {
        activePresetID = preset.id
        selectedTemplate = .blank
        weekdays = preset.suggestedWeekdays
        datesLessons = true
        if let credits = preset.suggestedCreditHours {
            hasCredits = true
            creditHours = credits
        }
        if courseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            courseTitle = preset.suggestedCourseTitle
        }
        let titles = preset.generateLessonTitles()
        lessonDrafts = titles.map { LessonDraft(title: $0) }
        appliedToast = "Loaded \(titles.count) lessons for \(preset.title)"
    }

    private func applyTemplate(_ template: CurriculumTemplateType) {
        activePresetID = nil
        selectedTemplate = template
        weekdays = template.suggestedWeekdays

        switch template {
        case .blank:
            if lessonDrafts.isEmpty {
                lessonDrafts = [LessonDraft(title: "Lesson 1")]
            }
            appliedToast = "Started with blank course"
        case .fourDayRhythm:
            datesLessons = true
            let titles = LessonPlanTemplateEngine.generateTitles(for: .fourDayRhythm)
            lessonDrafts = titles.map { LessonDraft(title: $0) }
            appliedToast = "Generated 144 lessons (36 weeks × 4 days)"
        case .fiveDayStandard:
            datesLessons = true
            let titles = LessonPlanTemplateEngine.generateTitles(for: .fiveDayStandard)
            lessonDrafts = titles.map { LessonDraft(title: $0) }
            appliedToast = "Generated 180 lessons (36 weeks × 5 days)"
        case .chapterPacing:
            let titles = LessonPlanTemplateEngine.generateTitles(
                for: .chapterPacing,
                chapterPrefix: chapterPrefix,
                chapterCount: chapterCount
            )
            lessonDrafts = titles.map { LessonDraft(title: $0) }
            appliedToast = "Generated \(titles.count) chapter lessons"
        case .batchPaste:
            if !pasteBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let titles = LessonPlanTemplateEngine.generateTitles(for: .batchPaste, rawPasteText: pasteBuffer)
                lessonDrafts = titles.map { LessonDraft(title: $0) }
                appliedToast = "Imported \(titles.count) lessons from outline"
            }
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Step Tabs Bar
                stepTabBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(Sage.background)

                Divider()

                // Content View according to selected step
                ScrollView {
                    VStack(spacing: 20) {
                        if store.presentedError != nil {
                            SaveErrorBanner()
                        }

                        switch currentStep {
                        case .starter:
                            starterStepView
                        case .schedule:
                            scheduleStepView
                        case .lessons:
                            lessonsStepView
                        case .learners:
                            learnersStepView
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Sage.background)

                Divider()

                // Bottom Navigation Footer
                bottomNavigationBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Sage.soft)
            }
            .navigationTitle("Build Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createCourse()
                    }
                    .disabled(!canCreateCourse)
                    .accessibilityIdentifier("saveCourse")
                }
            }
            .onAppear {
                displayedMonth = startOfMonth(for: startDate)
                selectedDate = startDate
            }
            .onChange(of: startDate) { _, newStart in
                displayedMonth = startOfMonth(for: newStart)
                selectedDate = newStart
            }
            .onChange(of: datesLessons) { _, enabled in
                if !enabled {
                    lessonViewMode = .list
                }
            }
        }
    }

    // MARK: - Step Tab Bar
    @ViewBuilder
    private var stepTabBar: some View {
        HStack(spacing: 6) {
            ForEach(SequenceBuilderStep.allCases) { step in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = step
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: step.icon)
                            .font(.caption2.weight(.bold))
                        Text(step.title)
                            .font(.caption.weight(currentStep == step ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(currentStep == step ? Sage.accent : Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(currentStep == step ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("builderTab-\(step.rawValue)")
            }
        }
    }

    // MARK: - Step 1: Starter
    @ViewBuilder
    private var starterStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Course & Curriculum Starter")
                    .font(.system(.title3, design: .serif, weight: .bold))
                Text("Name your course and choose a proven curriculum template or custom structure.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            courseTitleCard

            if let toast = appliedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Sage.accent)
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Sage.accent)
                    Spacer()
                    Button {
                        appliedToast = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Sage.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            categoryFilterBar

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(sectionHeaderTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(filteredItemCount) options")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Presets matching selectedCategory
                if selectedCategory != .custom {
                    ForEach(filteredPresets) { preset in
                        presetCard(preset)
                    }
                }

                // Custom structural tools (if .all or .custom)
                if selectedCategory == .all || selectedCategory == .custom {
                    if selectedCategory == .all {
                        Text("CUSTOM RHYTHMS & IMPORT TOOLS")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    ForEach(CurriculumTemplateType.allCases) { template in
                        templateCard(template)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CurriculumSubjectCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.caption.weight(.bold))
                            Text(category.rawValue)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Sage.accent : Sage.soft)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("categoryFilter-\(category.id)")
                }
            }
        }
    }

    @ViewBuilder
    private func presetCard(_ preset: CurriculumPreset) -> some View {
        let isSelected = activePresetID == preset.id

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                applyPreset(preset)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Sage.accent : Color.secondary.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: preset.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Sage.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(preset.style.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Sage.accent)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Sage.accent : Color.secondary.opacity(0.4))
                        }

                        Text(preset.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.primary)

                        Text(preset.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                // Badges row
                HStack(spacing: 6) {
                    Label(preset.badgeText, systemImage: "books.vertical.fill")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())

                    Label("\(preset.suggestedDaysPerWeek)-Day/Wk", systemImage: "calendar")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())

                    if let credits = preset.suggestedCreditHours {
                        Label(String(format: "%.1f Credit", credits), systemImage: "graduationcap.fill")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(isSelected ? Sage.accent.opacity(0.06) : Sage.soft)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Sage.accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("presetCard-\(preset.id)")
    }

    private func currentSubjectPrefix() -> String? {
        let trimmed = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        for subject in suggestedSubjects {
            if trimmed == subject || trimmed.hasPrefix("\(subject):") {
                return subject
            }
        }
        return nil
    }

    private func isSubjectSelected(_ subject: String) -> Bool {
        currentSubjectPrefix() == subject
    }

    private func selectSubject(_ subject: String) {
        let trimmed = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. If this subject is already active, toggle it off
        if let current = currentSubjectPrefix(), current == subject {
            if trimmed == subject {
                courseTitle = ""
            } else if trimmed.hasPrefix("\(subject): ") {
                courseTitle = String(trimmed.dropFirst("\(subject): ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("\(subject):") {
                courseTitle = String(trimmed.dropFirst("\(subject):".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return
        }

        // 2. If another subject was active, replace its prefix cleanly
        if let existing = currentSubjectPrefix() {
            if trimmed == existing {
                courseTitle = subject
            } else if trimmed.hasPrefix("\(existing): ") {
                let suffix = String(trimmed.dropFirst("\(existing): ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                courseTitle = "\(subject): \(suffix)"
            } else if trimmed.hasPrefix("\(existing):") {
                let suffix = String(trimmed.dropFirst("\(existing):".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                courseTitle = "\(subject): \(suffix)"
            } else {
                courseTitle = subject
            }
            return
        }

        // 3. If no suggested subject is currently recognized, clean up any previous chain and set single subject
        let parts = trimmed.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let nonSubjectParts = parts.filter { part in !suggestedSubjects.contains(part) && !part.isEmpty }
        if nonSubjectParts.isEmpty {
            courseTitle = subject
        } else {
            let customSuffix = nonSubjectParts.joined(separator: ": ")
            courseTitle = "\(subject): \(customSuffix)"
        }
    }

    @ViewBuilder
    private var courseTitleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COURSE TITLE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            TextField("e.g. 7th Grade Science, Math 4A, US History", text: $courseTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("courseTitle")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedSubjects, id: \.self) { subject in
                        let isSelected = isSubjectSelected(subject)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectSubject(subject)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(subject)
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? Sage.accent : Sage.accent.opacity(0.1))
                            .foregroundStyle(isSelected ? Color.white : Sage.accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("subjectChip-\(subject)")
                    }
                }
            }
        }
        .padding(14)
        .background(Sage.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func templateCard(_ template: CurriculumTemplateType) -> some View {
        let isSelected = selectedTemplate == template

        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    applyTemplate(template)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Sage.accent : Color.secondary.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: template.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Sage.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(template.tag.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Sage.accent)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Sage.accent : Color.secondary.opacity(0.4))
                        }

                        Text(template.shortTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.primary)

                        Text(template.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                templateEmbeddedControls(for: template)
            }
        }
        .padding(14)
        .background(isSelected ? Sage.accent.opacity(0.06) : Sage.soft)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Sage.accent : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func templateEmbeddedControls(for template: CurriculumTemplateType) -> some View {
        if template == .chapterPacing {
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Prefix")
                        .font(.subheadline)
                    Spacer()
                    TextField("e.g. Chapter", text: $chapterPrefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 130)
                }
                Stepper("Total Chapters: \(chapterCount)", value: $chapterCount, in: 1...180)
                    .font(.subheadline)
                Button {
                    applyTemplate(.chapterPacing)
                } label: {
                    Text("Generate \(chapterCount) \(chapterPrefix) Lessons")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Sage.accent.opacity(0.12))
                        .foregroundStyle(Sage.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        } else if template == .batchPaste {
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste syllabus (one line per lesson):")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextEditor(text: $pasteBuffer)
                    .frame(height: 90)
                    .padding(4)
                    .background(Color(uiColor: .systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Button {
                    applyTemplate(.batchPaste)
                } label: {
                    Text("Generate Lessons from Text")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Sage.accent.opacity(0.12))
                        .foregroundStyle(Sage.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(pasteBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Step 2: Schedule
    @ViewBuilder
    private var scheduleStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schedule & Calendar Pacing")
                    .font(.system(.title3, design: .serif, weight: .bold))
                Text("Set your school days and calendar start date before previewing lessons.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                Toggle("Put lessons on a calendar", isOn: $datesLessons)
                    .font(.headline)
                    .tint(Sage.accent)
                    .accessibilityIdentifier("datedLessonSchedule")

                if datesLessons {
                    Divider()

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        .font(.subheadline)

                    activeSchoolDaysView

                    if !lessonTitles.isEmpty {
                        Divider()
                        scheduleSummaryCard
                    }
                } else {
                    Text("Flexible lessons will be available in Plan without specific dates assigned.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Sage.soft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private var activeSchoolDaysView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVE SCHOOL DAYS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(weekdayNames, id: \.0) { weekday in
                    let isSelected = weekdays.contains(weekday.0)
                    Button {
                        if isSelected {
                            weekdays.remove(weekday.0)
                        } else {
                            weekdays.insert(weekday.0)
                        }
                    } label: {
                        Text(weekday.1)
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Sage.accent : Color.secondary.opacity(0.12))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(weekday.1) school day")
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("PACE & CADENCE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(lessonTitles.count) Lessons • \(weekdays.count) Days/Wk")
                    .font(.footnote.weight(.semibold))
                Text("Approx. \(totalWeeksCount) school weeks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("PROJECTED FINISH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(estimatedFinishDateString)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Sage.accent)
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 3: Lessons & Calendar Preview
    @ViewBuilder
    private var lessonsStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lessons & Calendar Preview")
                        .font(.system(.title3, design: .serif, weight: .bold))
                    Text("\(lessonDrafts.count) lessons planned • \(courseTitle.isEmpty ? "Subject" : courseTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Mode Selector: Calendar Preview vs List Editor
            Picker("View Mode", selection: $lessonViewMode) {
                Label("Calendar Preview", systemImage: "calendar").tag(LessonViewMode.calendar)
                Label("List Editor (\(lessonDrafts.count))", systemImage: "list.bullet").tag(LessonViewMode.list)
            }
            .pickerStyle(.segmented)

            if lessonViewMode == .calendar {
                calendarPreviewView
            } else {
                lessonListEditorView
            }
        }
    }

    // MARK: - Interactive Monthly Calendar Preview
    @ViewBuilder
    private var calendarPreviewView: some View {
        if !datesLessons {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(Sage.accent)
                Text("Flexible Lessons (No Dates)")
                    .font(.headline)
                Text("You've configured lessons without calendar dates in the Schedule tab. Switch to List Editor to edit lesson titles, or turn on calendar scheduling.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    withAnimation { currentStep = .schedule }
                } label: {
                    Text("Enable Calendar in Schedule Tab")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Sage.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Sage.soft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(spacing: 14) {
                // Month Header with navigation
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.bold))
                            .padding(8)
                            .background(Color.secondary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(monthYearTitle)
                        .font(.headline.weight(.bold))

                    Spacer()

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.bold))
                            .padding(8)
                            .background(Color.secondary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                // 7 Weekday Headers
                HStack(spacing: 0) {
                    ForEach(calendarHeaderDays, id: \.self) { day in
                        Text(day)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Month Days Grid
                let days = daysInMonth(for: displayedMonth)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(days.indices, id: \.self) { idx in
                        if let date = days[idx] {
                            calendarDayCell(date: date)
                        } else {
                            Color.clear
                                .frame(height: 50)
                        }
                    }
                }

                Divider().padding(.vertical, 4)

                // Selected Day Details Card
                selectedDayDetailCard
            }
            .padding(14)
            .background(Sage.soft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func calendarDayCell(date: Date) -> some View {
        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isSchoolDay = weekdays.contains(weekday)
        let preview = scheduledPreview(for: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : (isSchoolDay ? Color.primary : Color.secondary.opacity(0.6)))

                if let preview = preview {
                    Text("L\(preview.index)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : Sage.accent.opacity(0.2))
                        .foregroundStyle(isSelected ? Color.white : Sage.accent)
                        .clipShape(Capsule())
                } else if !isSchoolDay {
                    Text("Off")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary.opacity(0.5))
                } else {
                    Spacer().frame(height: 12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Sage.accent : (preview != nil ? Sage.accent.opacity(0.08) : Color(uiColor: .systemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Sage.accent : (preview != nil ? Sage.accent.opacity(0.3) : Color.clear), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDayDetailCard: some View {
        let formatter = DateFormatter()
        let _ = formatter.dateFormat = "EEEE, MMM d, yyyy"
        let dateString = formatter.string(from: selectedDate)
        let preview = scheduledPreview(for: selectedDate)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateString)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.primary)
                Spacer()
                if let preview = preview {
                    Text("Lesson \(preview.index)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Sage.accent.opacity(0.15))
                        .foregroundStyle(Sage.accent)
                        .clipShape(Capsule())
                }
            }

            if let preview = preview, let draftIndex = lessonDraftIndex(for: preview) {
                VStack(alignment: .leading, spacing: 6) {
                    if let week = preview.weekNumber, let day = preview.dayNumber {
                        Text("Week \(week), Day \(day) of school year")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(Sage.accent)
                        TextField("Lesson Title", text: $lessonDrafts[draftIndex].title)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Rest / Co-op Day (No lesson scheduled)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Lesson List Editor View
    @ViewBuilder
    private var lessonListEditorView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ALL LESSONS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation {
                        lessonDrafts.append(LessonDraft(title: "Lesson \(lessonDrafts.count + 1)"))
                    }
                } label: {
                    Label("Add Lesson", systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                }
                .accessibilityIdentifier("addLessonDraft")
            }

            ForEach(displayedDraftIndices, id: \.self) { index in
                lessonRow(at: index)
            }

            if lessonDrafts.count > 40 && !isShowingAllLessons {
                Button {
                    isShowingAllLessons = true
                } label: {
                    Text("Show All \(lessonDrafts.count) Lessons...")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                        .padding(.vertical, 8)
                }
            }

            Button {
                withAnimation {
                    lessonDrafts.append(LessonDraft(title: "Lesson \(lessonDrafts.count + 1)"))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Another Lesson")
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Sage.soft)
                .foregroundStyle(Sage.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func lessonRow(at index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(Sage.accent)
                .frame(width: 28, height: 28)
                .background(Sage.accent.opacity(0.12), in: Circle())

            TextField("Lesson title", text: $lessonDrafts[index].title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Lesson \(index + 1) title")
                .accessibilityIdentifier("lessonTitle-\(index + 1)")

            Button(role: .destructive) {
                withAnimation {
                    if index < lessonDrafts.count {
                        lessonDrafts.remove(at: index)
                    }
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete lesson \(index + 1)")
            .accessibilityIdentifier("deleteLessonDraft-\(index + 1)")
        }
        .padding(8)
        .background(Sage.soft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 4: Learners & Transcript
    @ViewBuilder
    private var learnersStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Learners & Transcript")
                    .font(.system(.title3, design: .serif, weight: .bold))
                Text("Select household students taking this course and review final details.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            studentSelectionCard

            transcriptCreditsCard

            gradingCategoriesCard

            courseSummaryCard

            createCourseButton
        }
    }

    @ViewBuilder
    private var studentSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ASSIGN LEARNERS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            if store.state.students.isEmpty {
                Text("No learners added yet. Add students in the Family tab.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.state.students) { student in
                    let isSelected = selectedStudents.contains(student.id)
                    Toggle(isOn: Binding(
                        get: { isSelected },
                        set: { enabled in
                            if enabled { selectedStudents.insert(student.id) } else { selectedStudents.remove(student.id) }
                        }
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Sage.accent : .secondary)
                            Text(student.name)
                                .font(.headline)
                        }
                    }
                    .tint(Sage.accent)
                    .accessibilityIdentifier("courseStudent-\(student.name)")
                }
            }
        }
        .padding(14)
        .background(Sage.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var transcriptCreditsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Award Academic Credits", isOn: $hasCredits)
                .font(.headline)
                .tint(Sage.accent)
                .accessibilityIdentifier("sequenceHasCreditsToggle")

            if hasCredits {
                Divider()

                HStack {
                    Text("Credit Hours")
                        .font(.subheadline)
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
                        .font(.subheadline)
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
        .padding(14)
        .background(Sage.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var gradingCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GRADING & WEIGHTING")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Assignment Weights")
                        .font(.headline)
                }
                Spacer()
                if categoryPreset != .equal {
                    let totalPercent = Int(round(totalCategoryWeight * 100))
                    HStack(spacing: 4) {
                        Image(systemName: totalPercent == 100 ? "checkmark.circle.fill" : (totalPercent > 100 ? "xmark.circle.fill" : "info.circle.fill"))
                            .font(.caption2)
                        Text("\(totalPercent)% Total")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        totalPercent == 100
                            ? Color.green.opacity(0.15)
                            : (totalPercent > 100 ? Color.red.opacity(0.15) : Color.orange.opacity(0.15)),
                        in: Capsule()
                    )
                    .foregroundStyle(
                        totalPercent == 100
                            ? Color.green
                            : (totalPercent > 100 ? Color.red : Color.orange)
                    )
                }
            }

            Picker("Grading Scheme", selection: $categoryPreset) {
                ForEach(GradeCategoryPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("sequenceGradingPresetPicker")
            .onChange(of: categoryPreset) {
                categoryDrafts = categoryPreset.defaultCategories
            }

            Text(categoryPreset.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if categoryPreset != .equal {
                Divider()

                VStack(spacing: 8) {
                    ForEach(categoryDrafts.indices, id: \.self) { idx in
                        HStack(spacing: 8) {
                            if categoryPreset == .custom {
                                TextField("Category Name", text: $categoryDrafts[idx].name)
                                    .font(.subheadline.weight(.semibold))
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Text(categoryDrafts[idx].name)
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()

                            let percent = Int(round(categoryDrafts[idx].weight * 100))
                            Menu {
                                ForEach(Array(stride(from: 5, through: 90, by: 5)), id: \.self) { p in
                                    Button("\(p)%") {
                                        categoryDrafts[idx].weight = Double(p) / 100.0
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(percent)%")
                                        .font(.subheadline.weight(.bold))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Sage.accent.opacity(0.12), in: Capsule())
                                .foregroundStyle(Sage.accent)
                            }

                            if categoryPreset == .custom {
                                Button(role: .destructive) {
                                    categoryDrafts.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if categoryPreset == .custom {
                        Button {
                            let available = max(0.05, min(0.50, 1.0 - totalCategoryWeight))
                            categoryDrafts.append(GradeCategoryDraft(name: "Category \(categoryDrafts.count + 1)", weight: available))
                        } label: {
                            Label("Add Custom Category", systemImage: "plus.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Sage.accent)
                        }
                        .padding(.top, 4)
                    }
                }

                if totalCategoryWeight > 1.001 {
                    Text("Total weight exceeds 100%. Adjust weights so the total does not exceed 100%.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if totalCategoryWeight < 0.999 && !categoryDrafts.isEmpty {
                    let unallocated = Int(round((1.0 - totalCategoryWeight) * 100))
                    Text("Remaining \(unallocated)% applies to uncategorized assignments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Sage.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var courseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COURSE SUMMARY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Course:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(courseTitle.isEmpty ? "(Untitled Course)" : courseTitle)
                    .font(.footnote.weight(.bold))
            }

            HStack {
                Text("Lessons:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(lessonDrafts.count) lessons (\(selectedTemplate.shortTitle))")
                    .font(.footnote)
            }

            HStack {
                Text("Learners:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(assignedStudentNames)
                    .font(.footnote)
            }

            HStack {
                Text("Pacing:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(datesLessons ? "\(weekdays.count) days/wk • Ends \(estimatedFinishDateString)" : "Flexible (Undated)")
                    .font(.footnote)
                    .foregroundStyle(Sage.accent)
            }

            HStack {
                Text("Grading:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(categoryPreset == .equal ? "Equal Weighting" : "\(categoryDrafts.count) Categories (\(Int(round(totalCategoryWeight * 100)))%)")
                    .font(.footnote)
                    .foregroundStyle(Sage.accent)
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Sage.accent.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var createCourseButton: some View {
        Button {
            createCourse()
        } label: {
            Text("Create Course")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canCreateCourse ? Sage.accent : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canCreateCourse)
    }

    // MARK: - Bottom Navigation Bar
    @ViewBuilder
    private var bottomNavigationBar: some View {
        HStack {
            if currentStep != .starter {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if let prev = SequenceBuilderStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = prev
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundStyle(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("builderBackButton")
            }

            Spacer()

            if currentStep != .learners {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if let next = SequenceBuilderStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = next
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(nextStepLabel)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Sage.accent)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("builderNextButton")
            }
        }
    }

    private var nextStepLabel: String {
        switch currentStep {
        case .starter: return "Next: Schedule"
        case .schedule: return "Next: Lessons & Calendar"
        case .lessons: return "Next: Learners"
        case .learners: return "Finish"
        }
    }

    // MARK: - Calendar Calculations
    private func startOfMonth(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: components) ?? date
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = startOfMonth(for: newMonth)
        }
    }

    private func daysInMonth(for monthDate: Date) -> [Date?] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2
        let start = startOfMonth(for: monthDate)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }

        let weekday = cal.component(.weekday, from: start)
        let leadingPadding = (weekday - cal.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingPadding)
        for day in 1...range.count {
            if let date = cal.date(byAdding: .day, value: day - 1, to: start) {
                days.append(date)
            }
        }

        let trailingPadding = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: trailingPadding))

        return days
    }

    private func scheduledPreview(for date: Date) -> ScheduledLessonPreview? {
        scheduledPreviews.first { preview in
            guard let pDate = preview.date else { return false }
            return Calendar.current.isDate(pDate, inSameDayAs: date)
        }
    }

    private func lessonDraftIndex(for preview: ScheduledLessonPreview) -> Int? {
        let idx = preview.index - 1
        return (idx >= 0 && idx < lessonDrafts.count) ? idx : nil
    }

    private func createCourse() {
        let credits = hasCredits ? creditHours : nil
        let w = hasCredits ? weight : nil
        let categoriesToCreate: [(name: String, weight: Double)] = categoryPreset == .equal
            ? []
            : categoryDrafts
                .map { ($0.name.trimmingCharacters(in: .whitespacesAndNewlines), $0.weight) }
                .filter { !$0.0.isEmpty }

        if store.addCourse(
            title: courseTitle,
            studentIDs: Array(selectedStudents),
            lessonTitles: lessonTitles,
            startDay: datesLessons ? SchoolDate.string(startDate) : nil,
            weekdays: weekdays,
            creditHours: credits,
            weight: w,
            gradeCategories: categoriesToCreate
        ) {
            dismiss()
        }
    }
}
