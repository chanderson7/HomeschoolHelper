import SwiftUI
import HomeschoolCore

struct FamilyView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var showAddStudent = false
    @State private var showPaywall = false
    @State private var editingStudent: Student?
    @State private var studentToDelete: Student?
    @State private var animateArt = false
    @State private var sunGlowPulse = false

    var body: some View {
        NavigationStack {
            List {
                Section {
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

                        // Seedlings & books art
                        Image("FamilyHeroArt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                            .offset(x: 10, y: -5)
                            .scaleEffect(animateArt ? 1.0 : 0.92)
                            .opacity(animateArt ? 1.0 : 0.0)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "leaf.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Sage.accent)
                                Text("Your learning team")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Sage.accent)
                            }
                            Text("Family")
                                .font(.system(.largeTitle, design: .serif, weight: .bold))
                            Text(store.state.students.isEmpty ? "Manage learner profiles and local settings." : "\(store.state.students.count) learner\(store.state.students.count == 1 ? "" : "s") growing together.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 95)
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
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .offset(x: 13, y: -13)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(student.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.primary)

                                        Text(student.gradeLevel.isEmpty ? "Grade level not set" : student.gradeLevel)
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

                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        if store.state.students.count >= 1 && !SubscriptionManager.shared.isPro {
                            showPaywall = true
                        } else {
                            showAddStudent = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Learner")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Sage.accent)
                    }
                    .accessibilityIdentifier("addStudent")
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showAddStudent) { AddStudentView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: $editingStudent) { student in
                EditStudentView(student: student)
            }
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
                    GradeLevelMenu(
                        selection: $gradeLevel,
                        accessibilityIdentifier: "editStudentGrade"
                    )
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

struct AddStudentView: View {
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
                    GradeLevelMenu(
                        selection: $gradeLevel,
                        accessibilityIdentifier: "studentGrade"
                    )
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
