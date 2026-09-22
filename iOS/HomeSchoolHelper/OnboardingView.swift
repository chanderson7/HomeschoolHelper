import SwiftUI
import HomeschoolCore

struct OnboardingView: View {
    @EnvironmentObject private var store: HomeschoolStore
    var onExplore: () -> Void

    enum Step {
        case child
        case subject
    }

    @State private var currentStep: Step = .child
    @State private var name = ""
    @State private var gradeLevel = ""
    @State private var selectedSubject = "Math"
    @State private var customSubject = ""
    @State private var cadence: CadenceOption = .schoolDays
    @State private var lessonCount = 5
    @State private var validationError: String?
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCustomSubjectFocused: Bool

    enum CadenceOption: String, CaseIterable, Identifiable {
        case schoolDays = "Every weekday (Mon–Fri)"
        case flexible = "Work at our own pace (Flexible)"

        var id: String { rawValue }
    }

    private let popularSubjects = ["Math", "Reading", "Language Arts", "Science", "History", "Custom"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Sage.soft)
                                .frame(width: 76, height: 76)
                            Image(systemName: currentStep == .child ? "sun.max.fill" : "book.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Sage.accent)
                        }
                        .padding(.top, 16)

                        Text(currentStep == .child ? "Welcome to\nHomeSchoolHelper" : "What is \(name.isEmpty ? "your learner" : name)\nlearning first?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text(currentStep == .child ? "Let’s set up your homeschool in less than a minute." : "Pick a starter subject. We’ll generate 5 starter lessons so you can jump right in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Step 1: Child details
                    if currentStep == .child {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Step 1: Who is learning?")
                                    .font(.headline)
                                Text("Enter your learner’s name and current grade level.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Learner's Name")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. Emma", text: $name)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                        .focused($isNameFocused)
                                        .accessibilityIdentifier("onboardingStudentName")
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Grade Level")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. Grade 1, Kindergarten, 9th Grade", text: $gradeLevel)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                        .accessibilityIdentifier("onboardingStudentGrade")
                                }
                            }

                            if let error = validationError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            Button {
                                proceedToSubject()
                            } label: {
                                HStack {
                                    Text("Continue to Subjects")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Sage.accent, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                            }
                            .accessibilityIdentifier("continueToSubject")
                        }
                        .padding(22)
                        .background(Sage.soft, in: RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 16)
                    } else {
                        // Step 2: Subject & Starter Lessons
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Step 2: Choose a starter subject")
                                    .font(.headline)
                                Text("You can add more subjects and edit lessons anytime.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Subject Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(popularSubjects, id: \.self) { subject in
                                    Button {
                                        selectedSubject = subject
                                        if subject == "Custom" {
                                            isCustomSubjectFocused = true
                                        }
                                    } label: {
                                        Text(subject)
                                            .font(.subheadline.weight(selectedSubject == subject ? .bold : .medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(selectedSubject == subject ? Sage.accent : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                            .foregroundStyle(selectedSubject == subject ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if selectedSubject == "Custom" {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Custom Subject Name")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. Nature Study, Art, Latin", text: $customSubject)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                        .focused($isCustomSubjectFocused)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Schedule Style")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Picker("Cadence", selection: $cadence) {
                                    ForEach(CadenceOption.allCases) { opt in
                                        Text(opt.rawValue).tag(opt)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Label("5 starter lessons will be created (Lesson 1 – Lesson 5)", systemImage: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let error = validationError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            Button {
                                completeSetup()
                            } label: {
                                HStack {
                                    Text("Finish & Start Learning")
                                        .font(.headline)
                                    Image(systemName: "checkmark")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Sage.accent, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                            }
                            .accessibilityIdentifier("saveOnboardingStudent")

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentStep = .child
                                }
                            } label: {
                                Text("Back to learner details")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(22)
                        .background(Sage.soft, in: RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 16)
                    }

                    // Secondary action: Explore first
                    Button(action: onExplore) {
                        Text("Explore without adding a subject")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("skipOnboarding")
                    .padding(.bottom, 24)
                }
            }
            .background(Sage.background.ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNameFocused = true
                }
            }
        }
    }

    private func proceedToSubject() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGrade = gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationError = "Please enter your learner's name."
            return
        }

        guard !trimmedGrade.isEmpty else {
            validationError = "Please enter a grade level."
            return
        }

        validationError = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = .subject
        }
    }

    private func completeSetup() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGrade = gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubject: String
        if selectedSubject == "Custom" {
            let customTrimmed = customSubject.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !customTrimmed.isEmpty else {
                validationError = "Please enter a custom subject name."
                return
            }
            finalSubject = customTrimmed
        } else {
            finalSubject = selectedSubject
        }

        validationError = nil

        // Add the student
        var newStudentID: UUID?
        _ = store.update("complete setup") { state in
            let studentID = try state.addStudent(name: trimmedName, gradeLevel: trimmedGrade)
            newStudentID = studentID
            
            // Seed 5 starter lessons
            let lessons = (1...5).map { "Lesson \($0)" }
            let startDay = cadence == .schoolDays ? SchoolDate.today : nil
            let weekdays: Set<Int> = [2, 3, 4, 5, 6]
            
            _ = try state.addCourse(
                title: finalSubject,
                studentIDs: [studentID],
                lessonTitles: lessons,
                startDay: startDay,
                weekdays: weekdays
            )
        }
    }
}

#Preview("Light Mode") {
    OnboardingView(onExplore: {})
        .environmentObject(HomeschoolStore())
}

#Preview("Dark Mode") {
    OnboardingView(onExplore: {})
        .environmentObject(HomeschoolStore())
        .preferredColorScheme(.dark)
}
