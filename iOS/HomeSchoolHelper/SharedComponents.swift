import SwiftUI
import HomeschoolCore

struct LoadFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your school records couldn’t be opened", systemImage: "exclamationmark.triangle")
        } description: {
            Text("No changes can be made until the saved data is available. \(message)")
        } actions: {
            Button("Try Again", action: retry).buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct SaveErrorBanner: View {
    @EnvironmentObject private var store: HomeschoolStore

    var body: some View {
        if let error = store.presentedError {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title).font(.headline)
                    Text(error.message).font(.footnote)
                }
                Spacer(minLength: 0)
                Button("Dismiss") { store.presentedError = nil }
                    .font(.caption.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("saveError")
        }
    }
}

struct StudentScopePicker: View {
    @EnvironmentObject private var store: HomeschoolStore
    let students: [Student]
    @Binding var selection: UUID?

    var body: some View {
        if !students.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All Learners" pill
                    let allAssignments = store.state.assignments.filter { $0.scheduledDay == SchoolDate.today }
                    let allCompleted = allAssignments.filter { $0.status == .completed }.count
                    let isAllSelected = selection == nil

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = nil }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("All")
                                .font(.subheadline.weight(isAllSelected ? .semibold : .regular))
                            if !allAssignments.isEmpty {
                                Text("\(allCompleted)/\(allAssignments.count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isAllSelected ? Color.white.opacity(0.25) : Sage.accent.opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isAllSelected ? Sage.accent : Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .foregroundStyle(isAllSelected ? .white : .primary)
                    }
                    .accessibilityLabel("Filter: All learners")
                    .accessibilityIdentifier("filterAllLearners")

                    // Individual Learner pills
                    ForEach(students) { student in
                        let isSelected = selection == student.id
                        let studentAssignments = store.state.assignments.filter { $0.studentID == student.id && $0.scheduledDay == SchoolDate.today }
                        let studentCompleted = studentAssignments.filter { $0.status == .completed }.count

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selection = student.id }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text(student.name)
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                if !studentAssignments.isEmpty {
                                    Text("\(studentCompleted)/\(studentAssignments.count)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? Color.white.opacity(0.25) : Sage.accent.opacity(0.15), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Sage.accent : Color(uiColor: .secondarySystemBackground), in: Capsule())
                            .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .accessibilityLabel("Filter: \(student.name)")
                        .accessibilityIdentifier("filterStudent-\(student.name)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct DayPicker: View {
    @Binding var day: String

    var body: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous day")
            Spacer()
            Text(SchoolDate.short(day)).font(.headline)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next day")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func shift(_ amount: Int) {
        guard let date = SchoolDate.date(day), let newDate = Calendar.current.date(byAdding: .day, value: amount, to: date) else { return }
        day = SchoolDate.string(newDate)
    }
}

struct ProgressCard: View {
    let completed: Int
    let total: Int
    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    private var percent: Int { total == 0 ? 0 : Int((Double(completed) / Double(total)) * 100) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DAILY ORBIT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Sage.accent)

                Text("\(completed) of \(total) lessons complete")
                    .font(.title3.weight(.bold))

                if total > 0 {
                    let remaining = total - completed
                    if remaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption.weight(.bold))
                            Text("\(remaining) lesson\(remaining == 1 ? "" : "s") remaining today")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                            Text("All scheduled work complete!")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(Sage.accent)
                    }
                } else {
                    Text("No lessons scheduled yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Preserved for automated accessibility audits and UITest assertions
                ProgressView(value: progress)
                    .tint(Sage.accent)
                    .accessibilityLabel("Family progress")
                    .accessibilityValue("\(completed) of \(total) lessons complete")
            }

            Spacer()

            // Circular Daily Orbit completion gauge
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, progress))))
                    .stroke(
                        Sage.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                VStack(spacing: 0) {
                    Text("\(percent)%")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Sage.accent)
                    Text("Done")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 68, height: 68)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct EmptyCard: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(detail))
            .frame(maxWidth: .infinity)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct Metric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SaveStatusToolbar: ToolbarContent {
    @EnvironmentObject private var store: HomeschoolStore
    @ObservedObject private var cloudSync = CloudSyncManager.shared

    var body: some ToolbarContent {
        ToolbarItem(placement: .status) {
            let labelText: String = {
                if store.isSaving {
                    return "Saving locally…"
                } else if cloudSync.syncStatus == .syncing {
                    return "Syncing to cloud…"
                } else {
                    return "Saved locally"
                }
            }()

            let iconName: String = {
                if store.isSaving || cloudSync.syncStatus == .syncing {
                    return "arrow.triangle.2.circlepath"
                } else if case .synced = cloudSync.syncStatus {
                    return "checkmark.icloud.fill"
                } else {
                    return "checkmark.icloud"
                }
            }()

            Label(labelText, systemImage: iconName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

extension AssignmentStatus {
    var readable: String {
        switch self {
        case .planned: "Planned"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .skipped: "Skipped"
        }
    }

    var symbol: String {
        switch self {
        case .planned: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .completed: "checkmark.circle.fill"
        case .skipped: "forward.fill"
        }
    }
}

func Hours(minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)m" }
    if remainder == 0 { return "\(hours)h" }
    return "\(hours)h \(remainder)m"
}
