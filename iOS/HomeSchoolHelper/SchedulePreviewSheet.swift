import SwiftUI

struct SchedulePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let courseTitle: String
    let previews: [ScheduledLessonPreview]
    let weekdaysCount: Int
    @State private var searchText = ""

    private var filteredPreviews: [ScheduledLessonPreview] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return previews
        }
        return previews.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.formattedDateString.localizedCaseInsensitiveContains(searchText) ||
            String($0.index).contains(searchText)
        }
    }

    private var finishDateString: String {
        previews.last?.formattedDateString ?? "Unknown"
    }

    private var startDateString: String {
        previews.first?.formattedDateString ?? "Unknown"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title2)
                                .foregroundStyle(Sage.accent)
                            VStack(alignment: .leading) {
                                Text(courseTitle.isEmpty ? "Course Schedule Preview" : courseTitle)
                                    .font(.headline)
                                Text("\(previews.count) Lessons • \(weekdaysCount) days / week")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STARTS")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(startDateString)
                                    .font(.footnote.weight(.semibold))
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("ESTIMATED FINISH")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(finishDateString)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Sage.accent)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Planned Lessons & Calendar Dates") {
                    if filteredPreviews.isEmpty {
                        Text("No matching lessons found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredPreviews) { item in
                            HStack(spacing: 12) {
                                Text("\(item.index)")
                                    .font(.caption.bold())
                                    .foregroundStyle(Sage.accent)
                                    .frame(width: 28, height: 28)
                                    .background(Sage.accent.opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                    if let week = item.weekNumber, let day = item.dayNumber {
                                        Text("Week \(week), Day \(day)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(item.formattedDateString)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search lessons or dates")
            .navigationTitle("Schedule Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
