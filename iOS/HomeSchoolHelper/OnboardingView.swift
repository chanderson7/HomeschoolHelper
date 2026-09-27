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

    private func iconForSubject(_ subject: String) -> String {
        switch subject {
        case "Math": return "📐"
        case "Reading": return "📚"
        case "Language Arts": return "✍️"
        case "Science": return "🔬"
        case "History": return "🧭"
        case "Custom": return "✨"
        default: return "📖"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Step Progress Indicator
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Sage.accent)
                                    .frame(width: 22, height: 22)
                                if currentStep == .subject {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("1")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text("Learner")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Sage.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Sage.accent.opacity(0.12), in: Capsule())

                        Rectangle()
                            .fill(currentStep == .subject ? Sage.accent : Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 2.5)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentStep)

                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(currentStep == .subject ? Sage.accent : Color(uiColor: .tertiarySystemFill))
                                    .frame(width: 22, height: 22)
                                Text("2")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(currentStep == .subject ? .white : .secondary)
                            }
                            Text("Starter Subject")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(currentStep == .subject ? Sage.accent : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(currentStep == .subject ? Sage.accent.opacity(0.12) : Color.clear, in: Capsule())
                    }
                    .padding(.top, 12)

                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.orange.opacity(0.18),
                                            Sage.soft,
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 8,
                                        endRadius: 55
                                    )
                                )
                                .frame(width: 90, height: 90)

                            Image("LoginHeroArt")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 72)
                                .accessibilityHidden(true)
                        }
                        .padding(.top, 4)

                        Text(currentStep == .child ? "Welcome to\nEZHomeschool" : "What is \(name.isEmpty ? "your learner" : name)\nlearning first?")
                            .font(.system(size: 28, weight: .bold, design: .serif))
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
                                    .font(.headline.weight(.bold))
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
                                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isNameFocused ? Sage.accent : Color.clear, lineWidth: 1.5)
                                        )
                                        .focused($isNameFocused)
                                        .accessibilityIdentifier("onboardingStudentName")
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Grade Level")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    GradeLevelMenu(
                                        selection: $gradeLevel,
                                        accessibilityIdentifier: "onboardingStudentGrade",
                                        usesFieldStyle: true,
                                        onSelect: { isNameFocused = false }
                                    )
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
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                proceedToSubject()
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Continue to Subjects")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Sage.accent, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(SpringScaleButtonStyle())
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
                                    .font(.headline.weight(.bold))
                                Text("You can add more subjects and edit lessons anytime.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Subject Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(popularSubjects, id: \.self) { subject in
                                    Button {
                                        #if os(iOS)
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        #endif
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedSubject = subject
                                        }
                                        if subject == "Custom" {
                                            isCustomSubjectFocused = true
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(iconForSubject(subject))
                                                .font(.title3)
                                            Text(subject)
                                                .font(.subheadline.weight(selectedSubject == subject ? .bold : .medium))
                                                .lineLimit(1)
                                            Spacer()
                                            if selectedSubject == subject {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .symbolEffect(.bounce, value: selectedSubject == subject)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(selectedSubject == subject ? Sage.accent : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                                        .foregroundStyle(selectedSubject == subject ? .white : .primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(selectedSubject == subject ? Sage.accent : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(SpringScaleButtonStyle())
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
                                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isCustomSubjectFocused ? Sage.accent : Color.clear, lineWidth: 1.5)
                                        )
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
                                #if os(iOS)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                #endif
                                completeSetup()
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Finish & Start Learning")
                                        .font(.headline)
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Sage.accent, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(SpringScaleButtonStyle())
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

                    // Secondary actions: Sample Household & Explore
                    VStack(spacing: 14) {
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            loadSampleHousehold()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                    .foregroundStyle(Sage.accent)
                                Text("Load Sample Household (Quick Demo)")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Sage.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Sage.accent.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(SpringScaleButtonStyle())
                        .accessibilityIdentifier("loadSampleHouseholdButton")

                        Button(action: onExplore) {
                            Text("Explore without adding a subject")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(SpringScaleButtonStyle())
                        .accessibilityIdentifier("skipOnboarding")
                    }
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
            validationError = "Please select a grade level."
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
        _ = store.update("complete setup") { state in
            let studentID = try state.addStudent(name: trimmedName, gradeLevel: trimmedGrade)
            
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

    private func loadSampleHousehold() {
        let sample = SampleDataGenerator.generateSampleState()
        _ = store.restore(sample)
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
