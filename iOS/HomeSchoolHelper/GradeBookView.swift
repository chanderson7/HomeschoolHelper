import SwiftUI
import HomeschoolCore

// MARK: - Grade Book View

struct GradeBookView: View {
    @EnvironmentObject var store: HomeschoolStore
    let course: Course
    let student: Student

    @State private var showAddCategory = false
    @State private var editingCategory: GradeCategory? = nil
    @State private var showDeleteCategoryAlert: GradeCategory? = nil

    private var categories: [GradeCategory] { store.gradeCategories(for: course.id) }
    private var totalWeight: Double { categories.reduce(0) { $0 + $1.weight } }
    private var lessons: [Lesson] { store.state.lessons.filter { $0.courseID == course.id } }

    private func assignment(for lesson: Lesson) -> Assignment? {
        store.state.assignments.first { $0.lessonID == lesson.id && $0.studentID == student.id }
    }

    private var courseAverage: Double? {
        store.courseGrade(for: student.id, courseID: course.id)
    }

    var body: some View {
        List {
            // Summary header
            courseHeaderSection

            // Category setup
            categoriesSection

            // Score ledger by category
            if !categories.isEmpty {
                ForEach(categories) { category in
                    scoreLedgerSection(for: category)
                }
                uncategorizedSection
            } else {
                allLessonsSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Grade Book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
                .disabled(totalWeight >= 1.0)
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddGradeCategorySheet(courseID: course.id, existingWeight: totalWeight)
                .environmentObject(store)
        }
        .sheet(item: $editingCategory) { category in
            EditGradeCategorySheet(category: category, existingWeight: totalWeight)
                .environmentObject(store)
        }
        .alert("Delete Category?", isPresented: Binding(
            get: { showDeleteCategoryAlert != nil },
            set: { if !$0 { showDeleteCategoryAlert = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let cat = showDeleteCategoryAlert {
                    store.deleteGradeCategory(id: cat.id)
                }
                showDeleteCategoryAlert = nil
            }
            Button("Cancel", role: .cancel) { showDeleteCategoryAlert = nil }
        } message: {
            Text("Assignments in this category will become uncategorized. This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var courseHeaderSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.title).font(.headline)
                        Text(student.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let avg = courseAverage {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f%%", avg))
                                .font(.title2.bold())
                                .foregroundStyle(gradeColor(avg))
                            if let letter = letterGrade(avg) {
                                Text(letter)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(gradeColor(avg).opacity(0.15), in: Capsule())
                                    .foregroundStyle(gradeColor(avg))
                            }
                        }
                    } else {
                        Text("No grades yet")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let avg = courseAverage, let credits = course.creditHours, credits > 0 {
                    Divider()
                    HStack {
                        Label("Credit Hours", systemImage: "graduationcap")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(credits, specifier: "%.1f") cr · \(avg >= 65 ? "Earned" : "Not Earned")")
                            .font(.caption.bold())
                            .foregroundStyle(avg >= 65 ? .green : .red)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var categoriesSection: some View {
        Section {
            if categories.isEmpty {
                Label("No grade categories yet. Tap + to add Tests, Homework, Projects, etc.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(categories) { category in
                    HStack {
                        Circle()
                            .fill(categoryColor(category).opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(String(category.name.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundStyle(categoryColor(category))
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name).font(.subheadline.bold())
                            if let avg = store.categoryGrade(for: student.id, categoryID: category.id) {
                                Text(String(format: "Avg: %.1f%%", avg)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", category.weight * 100))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { showDeleteCategoryAlert = category } label: { Label("Delete", systemImage: "trash") }
                        Button { editingCategory = category } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.blue)
                    }
                }

                // Weight bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(categoryColor(cat))
                                    .frame(width: geo.size.width * cat.weight)
                            }
                            if totalWeight < 1.0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: geo.size.width * (1.0 - totalWeight))
                            }
                        }
                    }
                    .frame(height: 8)
                    Text(String(format: "Total weight: %.0f%%", totalWeight * 100))
                        .font(.caption2)
                        .foregroundStyle(totalWeight > 1.001 ? .red : .secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Grade Categories")
        }
    }

    private func scoreLedgerSection(for category: GradeCategory) -> some View {
        let categoryLessons = lessons.filter { lesson in
            assignment(for: lesson)?.categoryID == category.id
        }
        let ungroupedLessons = lessons.filter { lesson in
            assignment(for: lesson)?.categoryID == nil
        }

        return Section {
            if categoryLessons.isEmpty {
                Text("No lessons assigned to this category yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(categoryLessons) { lesson in
                    ScoreRow(lesson: lesson, assignment: assignment(for: lesson), student: student, categories: categories)
                        .environmentObject(store)
                }
            }
        } header: {
            HStack {
                Circle()
                    .fill(categoryColor(category))
                    .frame(width: 8, height: 8)
                Text("\(category.name) · \(String(format: "%.0f%%", category.weight * 100))")
            }
        }
    }

    private var uncategorizedSection: some View {
        let uncategorized = lessons.filter { lesson in
            guard let asgn = assignment(for: lesson) else { return true }
            return asgn.categoryID == nil
        }
        return Group {
            if !uncategorized.isEmpty {
                Section {
                    ForEach(uncategorized) { lesson in
                        ScoreRow(lesson: lesson, assignment: assignment(for: lesson), student: student, categories: categories)
                            .environmentObject(store)
                    }
                } header: {
                    Text("Uncategorized Lessons")
                }
            }
        }
    }

    private var allLessonsSection: some View {
        Section("All Lessons") {
            ForEach(lessons) { lesson in
                ScoreRow(lesson: lesson, assignment: assignment(for: lesson), student: student, categories: [])
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Helpers

    private func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }

    private func letterGrade(_ grade: Double) -> String? {
        switch grade {
        case 97...: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A−"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B−"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C−"
        case 65..<70: return "D"
        default: return "F"
        }
    }

    private let categoryPalette: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .yellow]
    private func categoryColor(_ category: GradeCategory) -> Color {
        guard let idx = categories.firstIndex(where: { $0.id == category.id }) else { return .blue }
        return categoryPalette[idx % categoryPalette.count]
    }
}

// MARK: - Score Row

struct ScoreRow: View {
    @EnvironmentObject var store: HomeschoolStore
    let lesson: Lesson
    let assignment: Assignment?
    let student: Student
    let categories: [GradeCategory]

    @State private var scoreText: String = ""
    @State private var showCategoryPicker = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title).font(.subheadline)
                    if let status = assignment?.status {
                        Label(status.rawValue, systemImage: statusIcon(status))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // Score field
                HStack(spacing: 4) {
                    TextField("—", text: $scoreText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($isFocused)
                        .frame(width: 56)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: isFocused) { _, focused in
                            if !focused { commitScore() }
                        }
                    Text("%")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            if !categories.isEmpty, let asgn = assignment {
                // Category picker
                Menu {
                    Button("None") {
                        store.setAssignmentCategory(id: asgn.id, categoryID: nil)
                    }
                    ForEach(categories) { cat in
                        Button(cat.name) {
                            store.setAssignmentCategory(id: asgn.id, categoryID: cat.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let catID = asgn.categoryID,
                           let cat = categories.first(where: { $0.id == catID }) {
                            Label(cat.name, systemImage: "tag.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Label("Assign Category", systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            if let grade = assignment?.grade {
                scoreText = String(format: "%.0f", grade)
            }
        }
    }

    private func commitScore() {
        guard let asgn = assignment else { return }
        if scoreText.trimmingCharacters(in: .whitespaces).isEmpty {
            store.update("clear score") { state in
                try state.setAssignmentGrade(id: asgn.id, grade: nil)
            }
        } else if let value = Double(scoreText), value >= 0, value <= 100 {
            store.update("set score") { state in
                try state.setAssignmentGrade(id: asgn.id, grade: value)
            }
        }
    }

    private func statusIcon(_ status: AssignmentStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "clock.fill"
        case .skipped: return "arrow.right.circle"
        case .planned: return "circle"
        }
    }
}

// MARK: - Add Grade Category Sheet

struct AddGradeCategorySheet: View {
    @EnvironmentObject var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let courseID: UUID
    let existingWeight: Double

    @State private var name = ""
    @State private var weightPercent: Double = 30
    @State private var errorMessage: String? = nil

    private var maxWeightPercent: Double { min(100, (1.0 - existingWeight) * 100) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("e.g. Tests, Homework, Projects", text: $name)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            Text(String(format: "%.0f%%", weightPercent))
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        Slider(value: $weightPercent, in: 1...maxWeightPercent, step: 1)
                            .tint(.blue)
                        Text("Remaining budget: \(String(format: "%.0f%%", maxWeightPercent))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Weight")
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Add Grade Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let result = store.addGradeCategory(courseID: courseID, name: name, weight: weightPercent / 100)
        if result { dismiss() }
    }
}

// MARK: - Edit Grade Category Sheet

struct EditGradeCategorySheet: View {
    @EnvironmentObject var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let category: GradeCategory
    let existingWeight: Double

    @State private var name: String
    @State private var weightPercent: Double
    @State private var errorMessage: String? = nil

    init(category: GradeCategory, existingWeight: Double) {
        self.category = category
        self.existingWeight = existingWeight
        _name = State(initialValue: category.name)
        _weightPercent = State(initialValue: category.weight * 100)
    }

    private var maxWeightPercent: Double {
        let otherWeight = existingWeight - category.weight
        return min(100, (1.0 - otherWeight) * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("e.g. Tests, Homework, Projects", text: $name)
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            Text(String(format: "%.0f%%", weightPercent))
                                .font(.headline).foregroundStyle(.blue)
                        }
                        Slider(value: $weightPercent, in: 1...maxWeightPercent, step: 1)
                            .tint(.blue)
                    }
                } header: { Text("Weight") }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let result = store.updateGradeCategory(id: category.id, name: name, weight: weightPercent / 100)
        if result { dismiss() }
    }
}
