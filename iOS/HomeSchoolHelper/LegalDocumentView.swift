import SwiftUI

/// An accessible, dedicated viewer for legal documents like Privacy Policy and Terms of Service.
struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let documentType: LegalDocumentType

    private var document: LegalDocument { documentType.document }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Hero Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Sage.accent.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: documentType.iconName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Sage.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(documentType.title)
                                    .font(.title2.bold())
                                    .accessibilityAddTraits(.isHeader)
                                Text("Last updated \(documentType.lastUpdated)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(document.summary)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Sage.soft, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                    // Sections
                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                                .accessibilityAddTraits(.isHeader)

                            Text(section.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)

                            if let highlights = section.highlights, !highlights.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(highlights, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(Sage.accent)
                                                .padding(.top, 2)
                                            Text(item)
                                                .font(.footnote.weight(.medium))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Sage.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    }

                    // External Web Link Action
                    if let url = documentType.externalURL {
                        Link(destination: url) {
                            HStack {
                                Label("View on Website", systemImage: "arrow.up.right.square")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "safari")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityIdentifier("openExternalLegalLink")
                    }
                }
                .padding()
            }
            .background(Sage.background.ignoresSafeArea())
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("dismissLegalDocument")
                }
            }
            .accessibilityIdentifier("legalDocumentView-\(documentType.rawValue)")
        }
    }
}

#Preview {
    LegalDocumentView(documentType: .privacyPolicy)
}
