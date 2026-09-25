import SwiftUI
import HomeschoolCore

public struct ReadingLogView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStudentID: UUID? = nil
    @State private var selectedStatus: BookStatusFilter = .all
    @State private var searchText: String = ""
    @State private var showingAddBookSheet = false
    @State private var selectedBookForDetail: BookEntry? = nil

    private enum BookStatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case reading = "Reading"
        case completed = "Completed"
        case wantToRead = "Want to Read"

        var id: String { rawValue }

        var targetStatus: BookStatus? {
            switch self {
            case .all: return nil
            case .reading: return .reading
            case .completed: return .completed
            case .wantToRead: return .wantToRead
            }
        }
    }

    private var filteredBooks: [BookEntry] {
        store.books(for: selectedStudentID, status: selectedStatus.targetStatus)
            .filter { book in
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                let query = searchText.lowercased()
                let titleMatch = book.title.lowercased().contains(query)
                let authorMatch = book.author.lowercased().contains(query)
                let genreMatch = book.genre?.lowercased().contains(query) ?? false
                return titleMatch || authorMatch || genreMatch
            }
            .sorted { lhs, rhs in
                // Sort reading first, then completed by completedDay desc, then title
                if lhs.status == .reading && rhs.status != .reading { return true }
                if lhs.status != .reading && rhs.status == .reading { return false }
                if let rDate = rhs.completedDay, let lDate = lhs.completedDay {
                    return lDate > rDate
                }
                return lhs.title < rhs.title
            }
    }

    private var totalMinutesRead: Int {
        store.totalReadingMinutes(for: selectedStudentID)
    }

    private var completedBooksCount: Int {
        store.totalBooksCompleted(for: selectedStudentID)
    }

    private var activeBooksCount: Int {
        store.books(for: selectedStudentID, status: .reading).count
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    statsCard
                        .padding(.horizontal)

                    statusSegmentedControl
                        .padding(.horizontal)

                    if filteredBooks.isEmpty {
                        emptyStateView
                            .padding(.top, 30)
                            .padding(.horizontal)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBooks) { book in
                                BookCardView(book: book)
                                    .onTapGesture {
                                        selectedBookForDetail = book
                                    }
                                    .accessibilityIdentifier("bookCard_\(book.id.uuidString)")
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "Search titles, authors, genres")
            .navigationTitle("Reading Log & Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("doneReadingLog")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBookSheet = true
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addBookButton")
                }
            }
            .sheet(isPresented: $showingAddBookSheet) {
                AddBookView(defaultStudentID: selectedStudentID ?? store.state.students.first?.id)
            }
            .sheet(item: $selectedBookForDetail) { book in
                BookDetailView(bookID: book.id)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var filterBar: some View {
        if store.state.students.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedStudentID = nil
                    } label: {
                        Text("All Learners")
                            .font(.subheadline.weight(selectedStudentID == nil ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedStudentID == nil ? Sage.accent : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedStudentID == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("readingFilterAllStudents")

                    ForEach(store.state.students) { student in
                        let isSelected = selectedStudentID == student.id
                        Button {
                            selectedStudentID = student.id
                        } label: {
                            Text(student.name)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSelected ? Sage.accent : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("readingFilter_\(student.name)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(title: "READING", value: "\(activeBooksCount)", subtitle: "active books", icon: "book.fill")
            Divider().frame(height: 36)
            statItem(title: "COMPLETED", value: "\(completedBooksCount)", subtitle: "books finished", icon: "checkmark.circle.fill")
            Divider().frame(height: 36)
            let hours = Double(totalMinutesRead) / 60.0
            statItem(title: "HOURS", value: String(format: "%.1f", hours), subtitle: "\(totalMinutesRead) mins total", icon: "clock.fill")
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func statItem(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(Sage.accent)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusSegmentedControl: some View {
        Picker("Status", selection: $selectedStatus) {
            ForEach(BookStatusFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("readingStatusPicker")
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(Sage.accent.opacity(0.6))

            Text("No books found")
                .font(.headline)

            Text("Add books to track reading progress, total hours, and build an official book list for portfolio evaluations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                showingAddBookSheet = true
            } label: {
                Label("Add a Book", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Sage.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
            .accessibilityIdentifier("emptyStateAddBook")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Book Card View

struct BookCardView: View {
    @EnvironmentObject private var store: HomeschoolStore
    let book: BookEntry

    private var studentName: String {
        store.student(for: book.studentID)?.name ?? "Learner"
    }

    private var progressRatio: Double {
        guard let current = book.currentPage, let total = book.totalPages, total > 0 else { return 0 }
        return min(1.0, Double(current) / Double(total))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Book cover / icon pill
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(book.status == .completed ? Color.green.opacity(0.12) : Sage.accent.opacity(0.12))
                    .frame(width: 44, height: 60)

                Image(systemName: book.format.systemImage)
                    .font(.title3)
                    .foregroundStyle(book.status == .completed ? Color.green : Sage.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(book.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    statusBadge
                }

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let genre = book.genre, !genre.isEmpty {
                        Text(genre)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                    }

                    Text("· \(studentName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let rating = book.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Progress Bar (if totalPages known)
                if let total = book.totalPages, total > 0 {
                    let current = book.currentPage ?? 0
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: progressRatio)
                            .tint(book.status == .completed ? Color.green : Sage.accent)

                        HStack {
                            Text("Page \(current) of \(total)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progressRatio * 100))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch book.status {
        case .reading:
            Text("Reading")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Sage.accent.opacity(0.15), in: Capsule())
                .foregroundStyle(Sage.accent)
        case .completed:
            HStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                Text("Completed")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15), in: Capsule())
            .foregroundStyle(.green)
        case .wantToRead:
            Text("Want to Read")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.12), in: Capsule())
                .foregroundStyle(.blue)
        case .abandoned:
            Text("DNF")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Book Sheet

struct AddBookView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    var defaultStudentID: UUID?

    @State private var studentID: UUID
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var genre: String = ""
    @State private var format: BookFormat = .physical
    @State private var status: BookStatus = .reading
    @State private var totalPagesText: String = ""
    @State private var currentPageText: String = ""
    @State private var rating: Int = 0
    @State private var notes: String = ""
    @State private var startDay: String = SchoolDate.today
    @State private var completedDay: String = ""

    init(defaultStudentID: UUID? = nil) {
        self.defaultStudentID = defaultStudentID
        _studentID = State(initialValue: defaultStudentID ?? UUID())
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.state.students.count > 1 {
                    Section("Learner") {
                        Picker("Student", selection: $studentID) {
                            ForEach(store.state.students) { student in
                                Text(student.name).tag(student.id)
                            }
                        }
                    }
                }

                Section("Book Details") {
                    TextField("Title (e.g., Charlotte's Web)", text: $title)
                        .accessibilityIdentifier("bookTitleInput")
                    TextField("Author (e.g., E.B. White)", text: $author)
                        .accessibilityIdentifier("bookAuthorInput")
                    TextField("Genre (e.g., Classic Fiction, Science)", text: $genre)
                        .accessibilityIdentifier("bookGenreInput")

                    Picker("Format", selection: $format) {
                        ForEach(BookFormat.allCases) { fmt in
                            Label(fmt.rawValue, systemImage: fmt.systemImage).tag(fmt)
                        }
                    }

                    Picker("Status", selection: $status) {
                        ForEach(BookStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                }

                Section("Paging & Progress") {
                    HStack {
                        Text("Total Pages")
                        Spacer()
                        TextField("Optional", text: $totalPagesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("bookTotalPagesInput")
                    }

                    HStack {
                        Text("Current Page")
                        Spacer()
                        TextField("0", text: $currentPageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("bookCurrentPagesInput")
                    }
                }

                Section("Rating & Dates") {
                    HStack {
                        Text("Rating")
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(star <= rating ? .yellow : .secondary)
                                    .onTapGesture {
                                        rating = star == rating ? 0 : star
                                    }
                            }
                        }
                    }

                    HStack {
                        Text("Start Date")
                        Spacer()
                        TextField("YYYY-MM-DD", text: $startDay)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    if status == .completed {
                        HStack {
                            Text("Completed Date")
                            Spacer()
                            TextField("YYYY-MM-DD", text: $completedDay)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                    }
                }

                Section("Notes & Summary") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 70)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBook()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveBookButton")
                }
            }
            .onAppear {
                if let defaultID = defaultStudentID {
                    studentID = defaultID
                } else if let firstID = store.state.students.first?.id {
                    studentID = firstID
                }
            }
        }
    }

    private func saveBook() {
        let totalPages = Int(totalPagesText)
        let currentPage = Int(currentPageText)
        let finalRating = rating > 0 ? rating : nil
        let compDay = status == .completed ? (completedDay.isEmpty ? SchoolDate.today : completedDay) : nil

        let success = store.addBook(
            studentID: studentID,
            title: title,
            author: author,
            genre: genre.isEmpty ? nil : genre,
            format: format,
            status: status,
            totalPages: totalPages,
            currentPage: currentPage,
            rating: finalRating,
            notes: notes.isEmpty ? nil : notes,
            startDay: startDay.isEmpty ? nil : startDay,
            completedDay: compDay
        )

        if success {
            dismiss()
        }
    }
}

// MARK: - Book Detail View

struct BookDetailView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let bookID: UUID

    @State private var showingLogSessionSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private var book: BookEntry? {
        store.state.books.first { $0.id == bookID }
    }

    private var studentName: String {
        guard let book else { return "" }
        return store.student(for: book.studentID)?.name ?? "Learner"
    }

    private var sessions: [ReadingLogEntry] {
        store.readingLogs(bookID: bookID)
    }

    private var totalBookMinutes: Int {
        sessions.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        NavigationStack {
            if let book {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header banner
                        headerBanner(book: book)

                        // Quick Actions Bar
                        HStack(spacing: 12) {
                            Button {
                                showingLogSessionSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Log Session")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Sage.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("logReadingSessionButton")

                            if book.status != .completed {
                                Button {
                                    markAsCompleted(book: book)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle")
                                        Text("Mark Finished")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .accessibilityIdentifier("markBookCompletedButton")
                            }
                        }
                        .padding(.horizontal)

                        // Reading Progress Card
                        if let total = book.totalPages, total > 0 {
                            progressSection(book: book, total: total)
                                .padding(.horizontal)
                        }

                        // Notes section
                        if let notes = book.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("NOTES & REFLECTION")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .font(.subheadline)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }

                        // Session History Section
                        sessionHistorySection
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(book.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Label("Edit Book", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Book", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("bookDetailMenu")
                    }
                }
                .sheet(isPresented: $showingLogSessionSheet) {
                    LogReadingSessionView(book: book)
                }
                .sheet(isPresented: $showingEditSheet) {
                    EditBookView(book: book)
                }
                .alert("Delete Book?", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        if store.deleteBook(id: bookID) {
                            dismiss()
                        }
                    }
                } message: {
                    Text("This will remove '\(book.title)' and all logged reading sessions.")
                }
            } else {
                ContentUnavailableView("Book not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func headerBanner(book: BookEntry) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Sage.accent.opacity(0.12))
                    .frame(width: 54, height: 74)

                Image(systemName: book.format.systemImage)
                    .font(.title2)
                    .foregroundStyle(Sage.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("by \(book.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(book.format.rawValue)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())

                    if let genre = book.genre {
                        Text(genre)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }

                    Text("· \(studentName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let rating = book.rating {
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(star <= rating ? .yellow : .secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal)
    }

    private func progressSection(book: BookEntry, total: Int) -> some View {
        let current = book.currentPage ?? 0
        let ratio = min(1.0, Double(current) / Double(total))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("READING PROGRESS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Sage.accent)
            }

            ProgressView(value: ratio)
                .tint(book.status == .completed ? Color.green : Sage.accent)

            HStack {
                Text("Page \(current) of \(total)")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Stepper("", value: Binding(
                    get: { book.currentPage ?? 0 },
                    set: { newPage in
                        store.updateBook(id: book.id, currentPage: newPage)
                    }
                ), in: 0...total)
                .labelsHidden()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("READING SESSIONS (\(sessions.count))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                let hours = Double(totalBookMinutes) / 60.0
                Text(String(format: "Total: %.1f hrs (%d m)", hours, totalBookMinutes))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Sage.accent)
            }

            if sessions.isEmpty {
                Text("No reading sessions logged yet. Tap 'Log Session' above to record daily reading time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(SchoolDate.short(session.day))
                                    .font(.subheadline.weight(.semibold))
                                if let notes = session.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(session.minutes) min")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Sage.accent)

                                if let pages = session.pagesRead {
                                    Text("\(pages) pages")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Button {
                                store.deleteReadingLogEntry(id: session.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func markAsCompleted(book: BookEntry) {
        let total = book.totalPages ?? book.currentPage
        store.updateBook(
            id: book.id,
            status: .completed,
            currentPage: total,
            completedDay: SchoolDate.today
        )
    }
}

// MARK: - Log Reading Session View

struct LogReadingSessionView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let book: BookEntry

    @State private var day: String = SchoolDate.today
    @State private var minutes: Int = 30
    @State private var pagesReadText: String = ""
    @State private var notes: String = ""
    @State private var logToAttendance: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    HStack {
                        Text("Book")
                        Spacer()
                        Text(book.title).foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Date")
                        Spacer()
                        TextField("YYYY-MM-DD", text: $day)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Minutes Read")
                            Spacer()
                            Text("\(minutes) min").font(.headline).foregroundStyle(Sage.accent)
                        }

                        // Quick Minute Preset Buttons
                        HStack(spacing: 8) {
                            ForEach([15, 20, 30, 45, 60], id: \.self) { preset in
                                Button("\(preset)m") {
                                    minutes = preset
                                }
                                .font(.caption.weight(minutes == preset ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(minutes == preset ? Sage.accent : Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(minutes == preset ? .white : .primary)
                            }
                        }

                        Stepper("", value: $minutes, in: 5...360, step: 5)
                            .labelsHidden()
                    }

                    HStack {
                        Text("Pages Read")
                        Spacer()
                        TextField("Optional", text: $pagesReadText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("sessionPagesReadInput")
                    }
                }

                Section("Compliance Integration") {
                    Toggle("Log to Attendance & Hours", isOn: $logToAttendance)
                        .tint(Sage.accent)

                    Text("Automatically records instructional time under 'Reading: \(book.title)' in learning activities, contributing directly to statutory state attendance goals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Notes") {
                    TextField("Chapters read, discussion notes, questions", text: $notes)
                }
            }
            .navigationTitle("Log Reading Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .accessibilityIdentifier("saveReadingSessionButton")
                }
            }
        }
    }

    private func saveSession() {
        let pages = Int(pagesReadText)
        let success = store.addReadingLogEntry(
            bookID: book.id,
            studentID: book.studentID,
            day: day,
            minutes: minutes,
            pagesRead: pages,
            notes: notes.isEmpty ? nil : notes,
            logToAttendance: logToAttendance
        )
        if success {
            dismiss()
        }
    }
}

// MARK: - Edit Book View

struct EditBookView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss

    let book: BookEntry

    @State private var title: String
    @State private var author: String
    @State private var genre: String
    @State private var format: BookFormat
    @State private var status: BookStatus
    @State private var totalPagesText: String
    @State private var currentPageText: String
    @State private var rating: Int
    @State private var notes: String
    @State private var startDay: String
    @State private var completedDay: String

    init(book: BookEntry) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _genre = State(initialValue: book.genre ?? "")
        _format = State(initialValue: book.format)
        _status = State(initialValue: book.status)
        _totalPagesText = State(initialValue: book.totalPages != nil ? "\(book.totalPages!)" : "")
        _currentPageText = State(initialValue: book.currentPage != nil ? "\(book.currentPage!)" : "")
        _rating = State(initialValue: book.rating ?? 0)
        _notes = State(initialValue: book.notes ?? "")
        _startDay = State(initialValue: book.startDay ?? "")
        _completedDay = State(initialValue: book.completedDay ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Details") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Genre", text: $genre)

                    Picker("Format", selection: $format) {
                        ForEach(BookFormat.allCases) { fmt in
                            Label(fmt.rawValue, systemImage: fmt.systemImage).tag(fmt)
                        }
                    }

                    Picker("Status", selection: $status) {
                        ForEach(BookStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                }

                Section("Progress") {
                    HStack {
                        Text("Total Pages")
                        Spacer()
                        TextField("Optional", text: $totalPagesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Current Page")
                        Spacer()
                        TextField("0", text: $currentPageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section("Rating & Dates") {
                    HStack {
                        Text("Rating")
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(star <= rating ? .yellow : .secondary)
                                    .onTapGesture {
                                        rating = star == rating ? 0 : star
                                    }
                            }
                        }
                    }

                    HStack {
                        Text("Start Date")
                        Spacer()
                        TextField("YYYY-MM-DD", text: $startDay)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    HStack {
                        Text("Completed Date")
                        Spacer()
                        TextField("YYYY-MM-DD", text: $completedDay)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 70)
                }
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        let totalPages = Int(totalPagesText)
        let currentPage = Int(currentPageText)
        let finalRating = rating > 0 ? rating : nil

        let success = store.updateBook(
            id: book.id,
            title: title,
            author: author,
            genre: genre.isEmpty ? nil : genre,
            format: format,
            status: status,
            totalPages: totalPages,
            currentPage: currentPage,
            rating: finalRating,
            notes: notes.isEmpty ? nil : notes,
            startDay: startDay.isEmpty ? nil : startDay,
            completedDay: completedDay.isEmpty ? nil : completedDay
        )

        if success {
            dismiss()
        }
    }
}
