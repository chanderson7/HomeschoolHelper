import SwiftUI
import HomeschoolCore

struct FamilyView: View {
    @Environment(\.signedInIdentity) private var identity
    @State private var showAccount = false
    @EnvironmentObject private var store: HomeschoolStore
    @State private var showAddStudent = false
    @State private var editingStudent: Student?
    @State private var studentToDelete: Student?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your learning team").font(.caption.weight(.bold)).foregroundStyle(Sage.accent)
                        Text("Family").font(.largeTitle.bold())
                        Text("Manage learner profiles and local settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(student.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.primary)

                                        Text(student.gradeLevel.isEmpty ? "Grade level not set" : "Grade \(student.gradeLevel)")
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

                    Button("Add Learner", systemImage: "plus") { showAddStudent = true }
                        .font(.headline.weight(.semibold))
                        .accessibilityIdentifier("addStudent")
                }

                Section("Your data & privacy") {
                    if identity != nil {
                        Button("Account & cloud backups") { showAccount = true }
                            .accessibilityIdentifier("openAccount")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("App Settings & Legal", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("openSettingsFromFamily")
                    Label("Saved on this device", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(Sage.accent)
                    Text("Records are saved on this device for your signed-in account. You can create private cloud backups from Account & cloud backups.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showAccount) {
                if let identity { AccountView(identity: identity) }
            }
            .toolbar { SaveStatusToolbar() }
            .sheet(isPresented: $showAddStudent) { AddStudentView() }
            .sheet(item: $editingStudent) { student in
                EditStudentView(student: student)
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
                    TextField("Grade level", text: $gradeLevel).accessibilityIdentifier("editStudentGrade")
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

