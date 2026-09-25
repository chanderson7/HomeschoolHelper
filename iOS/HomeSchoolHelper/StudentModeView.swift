import SwiftUI
import HomeschoolCore

struct StudentModeView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var showingExitPINSheet = false
    @State private var selectedStudentID: UUID?

    private var students: [Student] {
        store.state.students
    }

    private var activeStudent: Student? {
        if let selectedStudentID, let match = students.first(where: { $0.id == selectedStudentID }) {
            return match
        }
        if let defaultID = store.activeStudentModeStudentID, let match = students.first(where: { $0.id == defaultID }) {
            return match
        }
        return students.first
    }

    private var todayAssignments: [Assignment] {
        guard let activeStudent else { return [] }
        return store.state.assignments.filter { assignment in
            assignment.studentID == activeStudent.id && assignment.scheduledDay == SchoolDate.today
        }
    }

    private var completedCount: Int {
        todayAssignments.filter { $0.status == .completed }.count
    }

    private var totalCount: Int {
        todayAssignments.count
    }

    private var progressRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Student switcher pill (if more than 1 student)
                        if students.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(students) { student in
                                        let isSelected = student.id == activeStudent?.id
                                        Button {
                                            selectedStudentID = student.id
                                            store.activeStudentModeStudentID = student.id
                                        } label: {
                                            Text(student.name)
                                                .font(.subheadline.weight(.semibold))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? Sage.accent : Color(.secondarySystemGroupedBackground))
                                                .foregroundStyle(isSelected ? .white : .primary)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 8)
                        }

                        // Greeting Card & Progress
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(greetingText)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text("Here’s what’s on your quest today:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()

                                ZStack {
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 6)
                                        .frame(width: 56, height: 56)
                                    Circle()
                                        .trim(from: 0, to: progressRatio)
                                        .stroke(Sage.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                        .frame(width: 56, height: 56)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.spring, value: progressRatio)

                                    if totalCount > 0 && completedCount == totalCount {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.title3)
                                    } else {
                                        Text("\(completedCount)/\(totalCount)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Sage.accent)
                                    }
                                }
                            }

                            if totalCount > 0 && completedCount == totalCount {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.yellow)
                                    Text("Quest Complete! You crushed every lesson today!")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Sage.accent)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Sage.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Assignments List
                        if todayAssignments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.orange)
                                Text("No lessons scheduled for today!")
                                    .font(.headline)
                                Text("Enjoy your free time, explore outside, or read a good book.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(32)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(todayAssignments) { assignment in
                                    StudentModeAssignmentCard(assignment: assignment)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Student Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Label(activeStudent?.name ?? "Learner", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Sage.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingExitPINSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Text("Exit")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("exitStudentModeButton")
                }
            }
            .sheet(isPresented: $showingExitPINSheet) {
                ExitStudentModePINSheet()
            }
        }
    }

    private var greetingText: String {
        let name = activeStudent?.name ?? "Champion"
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning, \(name)! ☀️"
        } else if hour < 17 {
            return "Good afternoon, \(name)! 🚀"
        } else {
            return "Good evening, \(name)! 🌙"
        }
    }
}

// MARK: - Student Mode Assignment Card

private struct StudentModeAssignmentCard: View {
    @EnvironmentObject private var store: HomeschoolStore
    let assignment: Assignment

    private var lesson: Lesson? {
        store.lesson(for: assignment.lessonID)
    }

    private var course: Course? {
        guard let lesson else { return nil }
        return store.course(for: lesson)
    }

    private var isCompleted: Bool {
        assignment.status == .completed
    }

    var body: some View {
        Button {
            toggleStatus()
        } label: {
            HStack(spacing: 16) {
                // Tactile check bead
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Sage.accent : Color(.systemGray4), lineWidth: 2.5)
                        .frame(width: 36, height: 36)

                    if isCompleted {
                        Circle()
                            .fill(Sage.accent)
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(course?.title ?? "Course")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Sage.accent)
                        .textCase(.uppercase)

                    Text(lesson?.title ?? "Lesson")
                        .font(.body.weight(.medium))
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted, color: .secondary)

                    if let notes = assignment.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isCompleted {
                    Text("Done!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Sage.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Sage.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCompleted ? Sage.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("studentAssignmentCard_\(assignment.id.uuidString)")
    }

    private func toggleStatus() {
        _ = store.toggleAssignmentStatus(assignment)
    }
}

// MARK: - Exit Student Mode PIN Sheet

private struct ExitStudentModePINSheet: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.dismiss) private var dismiss
    @State private var pin: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Sage.accent)

                VStack(spacing: 8) {
                    Text("Parent Authorization")
                        .font(.title2.weight(.bold))
                    Text(store.hasParentPIN
                         ? "Enter your 4-digit PIN to exit Student Mode and return to parent management."
                         : "No PIN is currently configured. Tap Exit to return to parent controls.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if store.hasParentPIN {
                    SecureField("4-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(width: 180)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: pin) {
                            if pin.count > 4 {
                                pin = String(pin.prefix(4))
                            }
                            if pin.count == 4 {
                                verifyAndExit()
                            }
                        }
                        .accessibilityIdentifier("parentPINInputField")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    verifyAndExit()
                } label: {
                    Text("Exit Student Mode")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Sage.accent)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("confirmExitStudentModeButton")

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func verifyAndExit() {
        if !store.hasParentPIN {
            store.isStudentModeActive = false
            store.activeStudentModeStudentID = nil
            dismiss()
            return
        }

        if store.exitStudentMode(pin: pin) {
            dismiss()
        } else {
            errorMessage = "Incorrect PIN. Please try again."
            pin = ""
        }
    }
}
