import Foundation

/// Represents the legal documents and policies available to users.
enum LegalDocumentType: String, Identifiable, CaseIterable {
    case privacyPolicy
    case termsOfService
    case openSourceLicenses

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsOfService: return "Terms of Service"
        case .openSourceLicenses: return "Open Source Licenses"
        }
    }

    var subtitle: String {
        switch self {
        case .privacyPolicy: return "How we safeguard your family's records & child privacy"
        case .termsOfService: return "Rules, educational responsibilities, and terms of use"
        case .openSourceLicenses: return "Software libraries and open source acknowledgments"
        }
    }

    var iconName: String {
        switch self {
        case .privacyPolicy: return "lock.shield.fill"
        case .termsOfService: return "doc.text.fill"
        case .openSourceLicenses: return "curlybraces"
        }
    }

    var lastUpdated: String {
        switch self {
        case .privacyPolicy: return "September 24, 2026"
        case .termsOfService: return "September 24, 2026"
        case .openSourceLicenses: return "September 2026"
        }
    }

    var externalURL: URL? {
        switch self {
        case .privacyPolicy:
            return URL(string: "https://homeschoohelp.netlify.app/privacy/")
        case .termsOfService:
            return URL(string: "https://homeschoohelp.netlify.app/")
        case .openSourceLicenses:
            return URL(string: "https://github.com/chanderson7/HomeschoolHelper")
        }
    }

    var document: LegalDocument {
        switch self {
        case .privacyPolicy:
            return LegalDocument(
                type: self,
                summary: "HomeSchoolHelper is built local-first. We do not sell your data, track children, or serve advertisements. Your family's educational records belong entirely to you.",
                sections: [
                    LegalSection(
                        title: "1. Local-First Data Sovereignty",
                        body: "HomeSchoolHelper operates on a Local-First architecture. All learner profiles, grade levels, course definitions, daily assignments, attendance records, and retrospective learning activities are stored locally on your device in secure app sandboxes. You can use all core features completely offline without internet connectivity.",
                        highlights: [
                            "Core data lives on your device first",
                            "Full offline capability for daily lessons and attendance",
                            "No automatic tracking or silent data transmission"
                        ]
                    ),
                    LegalSection(
                        title: "2. Information We Collect",
                        body: "When you choose to create an account, we collect your email address and password credentials to authenticate your account. If you elect to use our Private Cloud Backups, an immutable snapshot of your school state is securely transferred to your private cloud storage so you can recover your records if you switch or lose your device.",
                        highlights: [
                            "Account email is used strictly for authentication and account recovery",
                            "Cloud backups are only created when you choose to back up",
                            "We never access or inspect your family's educational records"
                        ]
                    ),
                    LegalSection(
                        title: "3. Children's Privacy (COPPA & Student Privacy)",
                        body: "We recognize the critical importance of protecting children's privacy in educational applications. HomeSchoolHelper is designed for use by parents, guardians, and educators.\n\n• We do not market to children or collect personal information directly from minors.\n• Learner names, grade levels, and learning milestones provided by parents are kept strictly within your private account boundary.\n• We do not perform student profiling, behavioral tracking, or analytics on child progress.\n• We do not sell, rent, or monetize student or family data under any circumstances.",
                        highlights: [
                            "Strict compliance with child privacy principles",
                            "Zero advertising and zero data brokering",
                            "All child information is parent-controlled"
                        ]
                    ),
                    LegalSection(
                        title: "4. Cloud Storage & Security",
                        body: "When cloud backups are enabled, data is stored in Supabase PostgreSQL infrastructure protected by Row Level Security (RLS) policies. Every backup record is locked to your authenticated parent user ID. Neither other users nor anonymous sessions can access, read, or modify your backups.",
                        highlights: [
                            "Row Level Security (RLS) enforces user isolation",
                            "Industry-standard encryption in transit (HTTPS/TLS) and at rest",
                            "Anonymous API access is strictly prohibited"
                        ]
                    ),
                    LegalSection(
                        title: "5. Your Rights: Export & Deletion",
                        body: "You maintain complete ownership of your educational records. You may delete individual learners, lessons, or attendance entries at any time. When you sign out or delete your account, your cloud backups can be deleted, and local device records can be cleared by deleting the application.",
                        highlights: [
                            "Delete your cloud backups at any time in Account & Backups",
                            "Full data exportability via standard JSON",
                            "Permanent deletion available upon parent request"
                        ]
                    ),
                    LegalSection(
                        title: "6. Contact Us",
                        body: "If you have questions regarding this Privacy Policy or your family's data, please contact us at privacy@homeschoolhelper.app.",
                        highlights: nil
                    )
                ]
            )
        case .termsOfService:
            return LegalDocument(
                type: self,
                summary: "These terms govern your use of HomeSchoolHelper. By using the app, you agree to these terms designed to support responsible homeschool record-keeping.",
                sections: [
                    LegalSection(
                        title: "1. Acceptance of Terms",
                        body: "By downloading, accessing, or using HomeSchoolHelper, you agree to be bound by these Terms of Service. If you do not agree with any part of these terms, please discontinue use of the application.",
                        highlights: nil
                    ),
                    LegalSection(
                        title: "2. Educational Utility & Parental Responsibility",
                        body: "HomeSchoolHelper is an organizational, scheduling, and record-keeping tool created for homeschooling parents and educators.\n\n• HomeSchoolHelper is not an accredited school, certified curriculum provider, or legal educational authority.\n• Parents and guardians remain solely responsible for complying with all applicable local, state, provincial, and national homeschool regulations, mandatory attendance days, curriculum standards, and reporting requirements in their jurisdiction.",
                        highlights: [
                            "App is an organizational utility, not an accredited school",
                            "Parents are responsible for state homeschool compliance",
                            "Attendance calculations are informational aids"
                        ]
                    ),
                    LegalSection(
                        title: "3. User Content & Ownership",
                        body: "You retain 100% intellectual property ownership of all student names, course titles, lesson outlines, schedules, notes, and records you input into HomeSchoolHelper. We claim no ownership over your educational materials or family data.",
                        highlights: [
                            "You own 100% of your curriculum and notes",
                            "We never use your educational content for marketing"
                        ]
                    ),
                    LegalSection(
                        title: "4. Account Security & Backups",
                        body: "You are responsible for maintaining the confidentiality of your account credentials. Because HomeSchoolHelper is local-first, we strongly encourage parents to periodically create private cloud backups or maintain device backups to prevent data loss in the event of hardware damage or device replacement.",
                        highlights: [
                            "Keep your account password secure",
                            "Regularly save private cloud backups"
                        ]
                    ),
                    LegalSection(
                        title: "5. Disclaimer of Warranties",
                        body: "HomeSchoolHelper is provided on an 'AS IS' and 'AS AVAILABLE' basis without warranties of any kind, whether express or implied. While we strive for absolute data durability and reliability, we do not guarantee that the service will be error-free or uninterrupted.",
                        highlights: nil
                    ),
                    LegalSection(
                        title: "6. Limitation of Liability",
                        body: "To the maximum extent permitted by law, HomeSchoolHelper and its creators shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use or inability to use the application.",
                        highlights: nil
                    )
                ]
            )
        case .openSourceLicenses:
            return LegalDocument(
                type: self,
                summary: "HomeSchoolHelper is built with the help of high quality open-source libraries and frameworks.",
                sections: [
                    LegalSection(
                        title: "Supabase Swift SDK",
                        body: "Copyright (c) 2022 Supabase Community\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.\n\nTHE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.",
                        highlights: ["MIT License", "Auth, PostgREST & Storage client"]
                    ),
                    LegalSection(
                        title: "Swift & Apple Frameworks",
                        body: "HomeSchoolHelper is written in Swift using SwiftUI, Foundation, and UIKit under Apple Inc.'s developer agreements and the open source Apache 2.0 license with Runtime Library Exception.",
                        highlights: ["Apple Developer Tools", "Apache 2.0 / Apple Platform SDK"]
                    )
                ]
            )
        }
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
