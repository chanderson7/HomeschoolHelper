import Foundation

/// Canonical website locations for customer-facing legal documents.
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://homeschoohelp.netlify.app/privacy/")!
    static let termsOfService = URL(string: "https://homeschoohelp.netlify.app/terms/")!
}

/// Native acknowledgments that are maintained with the app binary.
enum LegalDocumentType: String, Identifiable, CaseIterable {
    case openSourceLicenses

    var id: String { rawValue }
    var title: String { "Open Source Licenses" }
    var subtitle: String { "Software libraries and open source acknowledgments" }
    var iconName: String { "curlybraces" }
    var lastUpdated: String { "September 2026" }
    var externalURL: URL? { URL(string: "https://github.com/chanderson7/HomeschoolHelper") }

    var document: LegalDocument {
        LegalDocument(
            type: self,
            summary: "EZHomeschool is built with the help of high quality open-source libraries and frameworks.",
            sections: [
                LegalSection(
                    title: "Supabase Swift SDK",
                    body: "Copyright (c) 2022 Supabase Community\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.\n\nTHE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.",
                    highlights: ["MIT License", "Auth, PostgREST & Storage client"]
                ),
                LegalSection(
                    title: "Swift & Apple Frameworks",
                    body: "EZHomeschool is written in Swift using SwiftUI, Foundation, and UIKit under Apple Inc.'s developer agreements and the open source Apache 2.0 license with Runtime Library Exception.",
                    highlights: ["Apple Developer Tools", "Apache 2.0 / Apple Platform SDK"]
                )
            ]
        )
    }
}

/// A structured legal document model.
struct LegalDocument {
    let type: LegalDocumentType
    let summary: String
    let sections: [LegalSection]
}

/// A section within a legal document.
struct LegalSection: Identifiable {
    var id: String { title }
    let title: String
    let body: String
    let highlights: [String]?
}
