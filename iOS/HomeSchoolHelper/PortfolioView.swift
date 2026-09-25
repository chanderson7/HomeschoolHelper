import SwiftUI
import PhotosUI
import HomeschoolCore
#if canImport(UIKit)
import UIKit
#endif

public struct PortfolioView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStudentID: UUID? = nil
    @State private var selectedCourseID: UUID? = nil
    @State private var showingAddSheet = false
    @State private var selectedItemForDetail: PortfolioItem? = nil

    private var filteredItems: [PortfolioItem] {
        store.portfolioItems(
            for: selectedStudentID,
            courseID: selectedCourseID
        )
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 14)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if filteredItems.isEmpty {
                        emptyStateView
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredItems) { item in
                                PortfolioCardView(item: item)
                                    .onTapGesture {
                                        selectedItemForDetail = item
                                    }
                                    .accessibilityIdentifier("portfolioItemCard_\(item.id.uuidString)")
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Student Work Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Sample", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addPortfolioItemButton")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddPortfolioItemSheet(initialStudentID: selectedStudentID, initialCourseID: selectedCourseID)
            }
            .sheet(item: $selectedItemForDetail) { item in
                PortfolioDetailSheet(item: item)
            }
        }
        .accessibilityIdentifier("portfolioView")
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Menu {
                    Button("All Learners") { selectedStudentID = nil }
                    ForEach(store.state.students) { student in
                        Button(student.name) { selectedStudentID = student.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                        Text(selectedStudentName)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedStudentID == nil ? Color(.secondarySystemGroupedBackground) : Sage.accent.opacity(0.15))
                    .foregroundStyle(selectedStudentID == nil ? .primary : Sage.accent)
                    .clipShape(Capsule())
                }
                .accessibilityIdentifier("portfolioStudentFilter")

                Menu {
                    Button("All Subjects") { selectedCourseID = nil }
                    ForEach(store.state.courses) { course in
                        Button(course.title) { selectedCourseID = course.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book")
                        Text(selectedCourseName)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedCourseID == nil ? Color(.secondarySystemGroupedBackground) : Sage.accent.opacity(0.15))
                    .foregroundStyle(selectedCourseID == nil ? .primary : Sage.accent)
                    .clipShape(Capsule())
                }
                .accessibilityIdentifier("portfolioCourseFilter")

                Spacer()
            }
        }
    }

    private var selectedStudentName: String {
        guard let id = selectedStudentID, let student = store.student(for: id) else {
            return "All Learners"
        }
        return student.name
    }

    private var selectedCourseName: String {
        guard let id = selectedCourseID, let course = store.course(for: id) else {
            return "All Subjects"
        }
        return course.title
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Work Samples Found")
                .font(.headline)

            Text("Attach photos, artwork, test sheets, and writing samples to build an accredited student portfolio.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingAddSheet = true
            } label: {
                Label("Add First Sample", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Sage.accent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Portfolio Card View

private struct PortfolioCardView: View {
    @EnvironmentObject private var store: HomeschoolStore
    let item: PortfolioItem

    private var studentName: String {
        store.student(for: item.studentID)?.name ?? "Student"
    }

    private var courseTitle: String? {
        item.courseID.flatMap(store.course(for:))?.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color(.systemGray6)

                #if canImport(UIKit)
                if let uiImage = PortfolioStorage.shared.loadImage(fileName: item.imageFileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                #else
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                #endif
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(studentName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())

                    if let courseTitle {
                        Text(courseTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(SchoolDate.short(item.day))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Add Portfolio Item Sheet

public struct AddPortfolioItemSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    @State private var studentID: UUID
    @State private var title: String = ""
    @State private var day: Date = Date()
    @State private var courseID: UUID?
    @State private var assignmentID: UUID?
    @State private var notes: String = ""

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    #if canImport(UIKit)
    @State private var selectedImage: UIImage? = nil
    #endif
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    public init(
        initialStudentID: UUID? = nil,
        initialCourseID: UUID? = nil,
        initialAssignmentID: UUID? = nil,
        initialTitle: String? = nil
    ) {
        _studentID = State(initialValue: initialStudentID ?? UUID())
        _courseID = State(initialValue: initialCourseID)
        _assignmentID = State(initialValue: initialAssignmentID)
        _title = State(initialValue: initialTitle ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("Photo / Work Sample") {
                    #if canImport(UIKit)
                    if let selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 240)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button {
                                self.selectedImage = nil
                                self.selectedPhotoItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, Color.black.opacity(0.6))
                            }
                            .padding(8)
                        }
                    } else {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Sage.accent)
                                Text("Choose Photo or Scan")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Sage.accent)
                                Text("Select from photo library")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityIdentifier("portfolioPhotoPicker")
                    }
                    #else
                    Text("Photo picker requires iOS.")
                    #endif
                }

                Section("Details") {
                    Picker("Learner", selection: $studentID) {
                        ForEach(store.state.students) { student in
                            Text(student.name).tag(student.id)
                        }
                    }
                    .accessibilityIdentifier("portfolioItemStudentPicker")

                    TextField("Work Sample Title", text: $title)
                        .accessibilityIdentifier("portfolioItemTitleField")

                    DatePicker("Date", selection: $day, displayedComponents: .date)

                    Picker("Subject / Course (Optional)", selection: $courseID) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.state.courses) { course in
                            Text(course.title).tag(Optional(course.id))
                        }
                    }
                }

                Section("Teacher / Parent Notes (Optional)") {
                    TextField("Assessment notes, rubric results, or student reflections...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("portfolioItemNotesField")
                }
            }
            .navigationTitle("Add Work Sample")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSample()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPhotoMissing || isSaving)
                    .accessibilityIdentifier("savePortfolioItemButton")
                }
            }
            .onAppear {
                if studentID == UUID() || !store.state.students.contains(where: { $0.id == studentID }) {
                    if let first = store.state.students.first {
                        studentID = first.id
                    }
                }
            }
            .onChange(of: selectedPhotoItem) {
                loadSelectedPhoto()
            }
        }
    }

    private var isPhotoMissing: Bool {
        #if canImport(UIKit)
        return selectedImage == nil
        #else
        return true
        #endif
    }

    private func loadSelectedPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                #if canImport(UIKit)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = image
                    }
                }
                #endif
            }
        }
    }

    private func saveSample() {
        #if canImport(UIKit)
        guard let image = selectedImage else {
            errorMessage = "Please choose a photo for the work sample."
            return
        }
        isSaving = true
        errorMessage = nil

        do {
            let fileName = try PortfolioStorage.shared.saveImage(image)
            let dayString = SchoolDate.string(day)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

            let success = store.addPortfolioItem(
                studentID: studentID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                day: dayString,
                courseID: courseID,
                assignmentID: assignmentID,
                activityID: nil,
                imageFileName: fileName,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )

            if success {
                dismiss()
            } else {
                PortfolioStorage.shared.deleteImage(fileName: fileName)
                errorMessage = store.presentedError?.message ?? "Failed to save portfolio item."
                isSaving = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
        #endif
    }
}

// MARK: - Portfolio Detail Sheet

private struct PortfolioDetailSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let item: PortfolioItem

    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editNotes: String = ""
    @State private var editDay: Date = Date()
    @State private var showingDeleteAlert = false

    private var currentItem: PortfolioItem? {
        store.portfolioItem(for: item.id)
    }

    private var student: Student? {
        guard let current = currentItem else { return nil }
        return store.student(for: current.studentID)
    }

    private var course: Course? {
        guard let current = currentItem, let cID = current.courseID else { return nil }
        return store.course(for: cID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let current = currentItem {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            #if canImport(UIKit)
                            if let uiImage = PortfolioStorage.shared.loadImage(fileName: current.imageFileName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                            }
                            #endif

                            if isEditing {
                                editSection(current: current)
                            } else {
                                detailsSection(current: current)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("This work sample has been removed.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationTitle(currentItem?.title ?? "Work Sample")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Save") {
                            saveEdits()
                        }
                    } else if currentItem != nil {
                        Menu {
                            Button {
                                startEditing()
                            } label: {
                                Label("Edit Details", systemImage: "pencil")
                            }

                            #if canImport(UIKit)
                            if let current = currentItem {
                                let fileURL = PortfolioStorage.shared.fileURL(for: current.imageFileName)
                                ShareLink(item: fileURL) {
                                    Label("Share Photo", systemImage: "square.and.arrow.up")
                                }
                            }
                            #endif

                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Sample", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Delete Work Sample?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let current = currentItem {
                        store.deletePortfolioItem(id: current.id, imageFileName: current.imageFileName)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove this sample from the student's portfolio.")
            }
        }
    }

    private func detailsSection(current: PortfolioItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(current.title)
                .font(.title2.weight(.bold))

            HStack(spacing: 8) {
                Label(student?.name ?? "Student", systemImage: "person.fill")
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())

                if let course {
                    Label(course.title, systemImage: "book.closed")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }

                Label(SchoolDate.short(current.day), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let notes = current.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes & Assessment")
                        .font(.headline)
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func editSection(current: PortfolioItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Information")
                .font(.headline)

            TextField("Title", text: $editTitle)
                .textFieldStyle(.roundedBorder)

            DatePicker("Date", selection: $editDay, displayedComponents: .date)

            Text("Teacher Notes")
                .font(.subheadline.weight(.medium))
            TextEditor(text: $editNotes)
                .frame(height: 100)
                .padding(4)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startEditing() {
        guard let current = currentItem else { return }
        editTitle = current.title
        editNotes = current.notes ?? ""
        editDay = SchoolDate.date(current.day) ?? Date()
        isEditing = true
    }

    private func saveEdits() {
        guard let current = currentItem else { return }
        let dayString = SchoolDate.string(editDay)
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let success = store.updatePortfolioItem(
            id: current.id,
            title: trimmedTitle,
            day: dayString,
            notes: editNotes
        )
        if success {
            isEditing = false
        }
    }
}
