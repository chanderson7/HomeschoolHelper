import Foundation

// MARK: - Subject Categories

public enum CurriculumSubjectCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case math = "Math"
    case history = "History"
    case science = "Science"
    case languageArts = "Language Arts"
    case electives = "Electives & Faith"
    case custom = "Rhythms & Custom"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "sparkles"
        case .math: return "function"
        case .history: return "globe.americas.fill"
        case .science: return "atom"
        case .languageArts: return "character.book.closed.fill"
        case .electives: return "paintbrush.pointed.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Curriculum Preset Model

public struct CurriculumPreset: Identifiable {
    public let id: String
    public let title: String
    public let category: CurriculumSubjectCategory
    public let style: String
    public let summary: String
    public let lessonCount: Int
    public let suggestedDaysPerWeek: Int
    public let suggestedWeekdays: Set<Int>
    public let suggestedCourseTitle: String
    public let suggestedCreditHours: Double?
    public let badgeText: String
    public let icon: String
    public let generateLessonTitles: () -> [String]

    public init(
        id: String,
        title: String,
        category: CurriculumSubjectCategory,
        style: String,
        summary: String,
        lessonCount: Int,
        suggestedDaysPerWeek: Int,
        suggestedWeekdays: Set<Int>,
        suggestedCourseTitle: String,
        suggestedCreditHours: Double?,
        badgeText: String,
        icon: String,
        generateLessonTitles: @escaping () -> [String]
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.style = style
        self.summary = summary
        self.lessonCount = lessonCount
        self.suggestedDaysPerWeek = suggestedDaysPerWeek
        self.suggestedWeekdays = suggestedWeekdays
        self.suggestedCourseTitle = suggestedCourseTitle
        self.suggestedCreditHours = suggestedCreditHours
        self.badgeText = badgeText
        self.icon = icon
        self.generateLessonTitles = generateLessonTitles
    }
}

// MARK: - Pre-Built Curriculum Catalog

extension CurriculumPreset {
    public static let catalog: [CurriculumPreset] = [
        // --- MATH ---
        CurriculumPreset(
            id: "math-spiral-120",
            title: "Spiral Math & Investigations",
            category: .math,
            style: "Incremental Spiral (Saxon-Style)",
            summary: "120 incremental daily lessons plus 12 periodic deep-dive investigations and cumulative review checkpoints.",
            lessonCount: 132,
            suggestedDaysPerWeek: 5,
            suggestedWeekdays: [2, 3, 4, 5, 6], // Mon - Fri
            suggestedCourseTitle: "Math: Spiral Foundations",
            suggestedCreditHours: 1.0,
            badgeText: "120 Lessons + 12 Tests",
            icon: "number.square.fill",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(132)
                var investigationCount = 1
                for lesson in 1...120 {
                    titles.append("Lesson \(lesson): Practice & Problem Solving")
                    if lesson % 10 == 0 && investigationCount <= 12 {
                        titles.append("Investigation \(investigationCount): In-Depth Exploration & Cumulative Review")
                        investigationCount += 1
                    }
                }
                return titles
            }
        ),
        CurriculumPreset(
            id: "math-mastery-30",
            title: "Concept Mastery Math",
            category: .math,
            style: "Unit Mastery (Math-U-See / Singapore)",
            summary: "30 foundational units with concept intro, manipulatives, application, and end-of-unit assessments.",
            lessonCount: 60,
            suggestedDaysPerWeek: 5,
            suggestedWeekdays: [2, 3, 4, 5, 6],
            suggestedCourseTitle: "Math: Core Mastery",
            suggestedCreditHours: 1.0,
            badgeText: "30 Units (60 Sessions)",
            icon: "square.grid.3x3.square",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(60)
                for unit in 1...30 {
                    titles.append("Unit \(unit)A: Concept Exploration & Guided Practice")
                    titles.append("Unit \(unit)B: Application & Unit Assessment")
                }
                return titles
            }
        ),

        // --- HISTORY ---
        CurriculumPreset(
            id: "history-chronological-42",
            title: "Chronological World History",
            category: .history,
            style: "Narrative (Story of the World)",
            summary: "42 narrative history chapters paired with map work, historical timeline entries, and comprehension reviews.",
            lessonCount: 84,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5], // Mon - Thu
            suggestedCourseTitle: "World History: Ancient to Modern",
            suggestedCreditHours: 1.0,
            badgeText: "42 Chapters (84 Sessions)",
            icon: "book.pages.fill",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(84)
                for ch in 1...42 {
                    titles.append("Chapter \(ch): Narrative Reading & Oral Narration")
                    titles.append("Chapter \(ch): Map Work & Primary Project")
                }
                return titles
            }
        ),
        CurriculumPreset(
            id: "history-us-36",
            title: "US History & Primary Sources",
            category: .history,
            style: "Document & Living Literature",
            summary: "36 eras of American history studied through living literature, historical source documents, and semester projects.",
            lessonCount: 72,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5],
            suggestedCourseTitle: "United States History & Civics",
            suggestedCreditHours: 1.0,
            badgeText: "36 Eras (72 Sessions)",
            icon: "flag.fill",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(72)
                for era in 1...36 {
                    titles.append("Era \(era): Historical Reading & Timeline")
                    titles.append("Era \(era): Primary Source Document & Essay Prompt")
                }
                return titles
            }
        ),

        // --- SCIENCE ---
        CurriculumPreset(
            id: "science-immersion-28",
            title: "Young Explorer Immersion Science",
            category: .science,
            style: "Immersion Modules (Apologia-Style)",
            summary: "28 focused scientific modules paced in 2-week blocks with hands-on lab experiments and science notebooking.",
            lessonCount: 56,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5],
            suggestedCourseTitle: "Science: Exploring Creation",
            suggestedCreditHours: 1.0,
            badgeText: "28 Modules (56 Sessions)",
            icon: "allergens",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(56)
                for mod in 1...28 {
                    titles.append("Module \(mod): Text Exploration & Vocabulary")
                    titles.append("Module \(mod): Hands-On Experiment & Lab Report")
                }
                return titles
            }
        ),
        CurriculumPreset(
            id: "science-nature-36",
            title: "Living Nature & Field Study",
            category: .science,
            style: "Charlotte Mason Nature Study",
            summary: "36 seasonal field walks, natural history readings, specimen collections, and nature journal sketches.",
            lessonCount: 36,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5],
            suggestedCourseTitle: "Science: Living Nature Study",
            suggestedCreditHours: 0.5,
            badgeText: "36 Weekly Field Studies",
            icon: "leaf.fill",
            generateLessonTitles: {
                let topics = [
                    "Autumn Tree Identification & Leaf Rubbings", "Seed Dispersal & Wildflower Specimen",
                    "Bird Migration & Field Guide Sketching", "Pond Water Ecology & Microscopic Life",
                    "Soil Layers & Underground Insects", "Bark Textures & Winter Tree Silhouettes",
                    "Winter Bird Feeder Observations", "Snow Crystals, Frost & Weather Station",
                    "Animal Tracks & Woodland Signs", "Conifers, Pinecones & Evergreens",
                    "Night Sky Constellations & Lunar Cycles", "Rock Types, Minerals & Hardness Testing",
                    "Fossils & Geological Formations", "Signs of Early Spring & Tree Budding",
                    "Spring Bird Songs & Territory Mapping", "Sprouting Bulbs & Garden Prep",
                    "Worms, Soil Aeration & Compost Study", "Wild edible Plants & Poisonous Plants",
                    "Butterfly Life Cycle & Metamorphosis", "Honeybees & Pollination Observations",
                    "Tadpole Development in Local Streams", "Mushroom & Fungi Growth Patterns",
                    "Freshwater Stream Quality & Critter Count", "Fern Varieties & Spore Examination",
                    "Summer Solstice & Sun Dial Tracking", "Spider Webs, Types & Silk Mechanics",
                    "Ant Colony Structures & Foraging Trails", "Weather Patterns, Clouds & Barometric Trends",
                    "Moss & Lichen Microhabitats", "Grass Varieties & Agricultural Grains",
                    "Night Insects & Moths Exploration", "River Erosion & Watershed Mapping",
                    "Dragonflies, Damselflies & Pond Borders", "Wild Berry Identification & Birds",
                    "Deciduous Forest Canopy Levels", "End-of-Year Nature Portfolio Reflection"
                ]
                return topics.enumerated().map { index, topic in
                    "Week \(index + 1): \(topic)"
                }
            }
        ),

        // --- LANGUAGE ARTS ---
        CurriculumPreset(
            id: "language-livingbooks-36",
            title: "Living Books & Narration",
            category: .languageArts,
            style: "Charlotte Mason 4-Day Rhythm",
            summary: "36 weeks of living classic literature, oral narration, copywork penmanship, and poetry appreciation.",
            lessonCount: 144,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5], // Mon - Thu
            suggestedCourseTitle: "Language Arts: Living Literature",
            suggestedCreditHours: 1.0,
            badgeText: "36 Weeks (144 Days)",
            icon: "text.book.closed.fill",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(144)
                for w in 1...36 {
                    titles.append("Week \(w), Day 1: Classic Literature Reading & Narration")
                    titles.append("Week \(w), Day 2: Copywork & Penmanship")
                    titles.append("Week \(w), Day 3: Dictation, Grammar & Phonics")
                    titles.append("Week \(w), Day 4: Poetry Recitation & Picture Study")
                }
                return titles
            }
        ),
        CurriculumPreset(
            id: "language-phonics-30",
            title: "Phonics & Spelling Mastery",
            category: .languageArts,
            style: "Orton-Gillingham (All About Spelling)",
            summary: "30 sequential phonetic concept steps with letter tiles, dictation sentences, and phonogram reviews.",
            lessonCount: 60,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5],
            suggestedCourseTitle: "Language Arts: Phonics & Spelling",
            suggestedCreditHours: 0.5,
            badgeText: "30 Steps (60 Sessions)",
            icon: "pencil.and.scribble",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(60)
                for step in 1...30 {
                    titles.append("Step \(step): Phonogram Rule & Letter Tiles")
                    titles.append("Step \(step): Dictation Sentences & Review")
                }
                return titles
            }
        ),

        // --- ELECTIVES & FAITH ---
        CurriculumPreset(
            id: "electives-scripture-180",
            title: "Daily Scripture & Character",
            category: .electives,
            style: "Daily Devotional Rhythm",
            summary: "180 daily readings covering scripture passages, proverb memorization, and character habit discussions.",
            lessonCount: 180,
            suggestedDaysPerWeek: 5,
            suggestedWeekdays: [2, 3, 4, 5, 6], // Mon - Fri
            suggestedCourseTitle: "Bible: Daily Scripture & Character",
            suggestedCreditHours: 1.0,
            badgeText: "180 Daily Readings",
            icon: "heart.text.square.fill",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(180)
                for day in 1...180 {
                    titles.append("Day \(day): Scripture Reading & Character Reflection")
                }
                return titles
            }
        ),
        CurriculumPreset(
            id: "electives-finearts-18",
            title: "Fine Arts & Composer Study",
            category: .electives,
            style: "Bi-Weekly Arts Enrichment",
            summary: "18 composer and visual artist studies with guided music listening and picture reproduction analysis.",
            lessonCount: 36,
            suggestedDaysPerWeek: 4,
            suggestedWeekdays: [2, 3, 4, 5],
            suggestedCourseTitle: "Fine Arts: Music & Art Appreciation",
            suggestedCreditHours: 0.5,
            badgeText: "18 Units (36 Sessions)",
            icon: "music.note.house.fill",
            generateLessonTitles: {
                var titles: [String] = []
                titles.reserveCapacity(36)
                for unit in 1...18 {
                    titles.append("Unit \(unit): Artist Biography & Picture Study")
                    titles.append("Unit \(unit): Composer Profile & Guided Listening")
                }
                return titles
            }
        )
    ]
}

// MARK: - Legacy Curriculum Template Types (For backward compatibility & custom tools)

public enum CurriculumTemplateType: String, CaseIterable, Identifiable {
    case blank = "Custom / Blank"
    case fourDayRhythm = "36-Week 4-Day Rhythm (144 Days)"
    case fiveDayStandard = "36-Week 5-Day Standard (180 Days)"
    case chapterPacing = "Chapter / Textbook Pacing"
    case batchPaste = "Paste Syllabus / Outline"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .blank: return "square.and.pencil"
        case .fourDayRhythm: return "sun.max.fill"
        case .fiveDayStandard: return "calendar.badge.clock"
        case .chapterPacing: return "book.closed.fill"
        case .batchPaste: return "doc.on.clipboard.fill"
        }
    }

    public var description: String {
        switch self {
        case .blank:
            return "Start with an empty lesson list and add lessons individually."
        case .fourDayRhythm:
            return "Popular Sonlight & Classical rhythm (Mon–Thu, 144 days) leaving Friday free for co-ops or field trips."
        case .fiveDayStandard:
            return "Standard full-year academic schedule (Mon–Fri, 180 days) evenly spaced across 36 weeks."
        case .chapterPacing:
            return "Generate numbered chapters, units, or modules with custom pacing."
        case .batchPaste:
            return "Paste an outline, syllabus, or table of contents (one per line) to create all lessons instantly."
        }
    }

    public var shortTitle: String {
        switch self {
        case .blank: return "Custom Course"
        case .fourDayRhythm: return "4-Day Rhythm (144 Days)"
        case .fiveDayStandard: return "5-Day Standard (180 Days)"
        case .chapterPacing: return "Chapter Pacing"
        case .batchPaste: return "Paste Syllabus"
        }
    }

    public var tag: String {
        switch self {
        case .blank: return "Blank Canvas"
        case .fourDayRhythm: return "Sonlight / Classical"
        case .fiveDayStandard: return "Academic Year"
        case .chapterPacing: return "Textbook Units"
        case .batchPaste: return "Quick Import"
        }
    }

    public var suggestedWeekdays: Set<Int> {
        switch self {
        case .fourDayRhythm:
            return [2, 3, 4, 5] // Mon - Thu
        default:
            return [2, 3, 4, 5, 6] // Mon - Fri
        }
    }
}

// MARK: - Scheduled Lesson Preview Model

public struct ScheduledLessonPreview: Identifiable {
    public let id = UUID()
    public let index: Int
    public let title: String
    public let date: Date?
    public let weekNumber: Int?
    public let dayNumber: Int?

    public var formattedDateString: String {
        guard let date = date else { return "Flexible (No Date)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Template Engine

public enum LessonPlanTemplateEngine {
    /// Generates lesson titles for a chosen curriculum template
    public static func generateTitles(
        for template: CurriculumTemplateType,
        courseTitle: String = "",
        chapterPrefix: String = "Chapter",
        chapterCount: Int = 30,
        rawPasteText: String = ""
    ) -> [String] {
        switch template {
        case .blank:
            return ["Lesson 1"]

        case .fourDayRhythm:
            // 36 weeks x 4 days = 144 lessons
            var titles: [String] = []
            titles.reserveCapacity(144)
            for week in 1...36 {
                for day in 1...4 {
                    titles.append("Week \(week), Day \(day)")
                }
            }
            return titles

        case .fiveDayStandard:
            // 36 weeks x 5 days = 180 lessons
            var titles: [String] = []
            titles.reserveCapacity(180)
            for week in 1...36 {
                for day in 1...5 {
                    titles.append("Week \(week), Day \(day)")
                }
            }
            return titles

        case .chapterPacing:
            let count = max(1, min(chapterCount, 365))
            let prefix = chapterPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Lesson" : chapterPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            return (1...count).map { "\(prefix) \($0)" }

        case .batchPaste:
            let lines = rawPasteText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return lines.isEmpty ? ["Lesson 1"] : lines
        }
    }

    /// Calculates dates for all lessons based on a start date and active weekdays
    public static func previewSchedule(
        titles: [String],
        startDate: Date,
        weekdays: Set<Int>,
        datesLessons: Bool
    ) -> [ScheduledLessonPreview] {
        guard datesLessons, !weekdays.isEmpty else {
            return titles.enumerated().map { index, title in
                ScheduledLessonPreview(
                    index: index + 1,
                    title: title,
                    date: nil,
                    weekNumber: nil,
                    dayNumber: nil
                )
            }
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        var currentDate = calendar.startOfDay(for: startDate)
        var previews: [ScheduledLessonPreview] = []
        previews.reserveCapacity(titles.count)

        var titleIndex = 0
        var safetyCounter = 0
        let maxIterations = 365 * 4 // Max 4 years out

        while titleIndex < titles.count && safetyCounter < maxIterations {
            safetyCounter += 1
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekdays.contains(weekday) {
                let weekNum = (titleIndex / max(1, weekdays.count)) + 1
                let dayNum = (titleIndex % max(1, weekdays.count)) + 1
                previews.append(
                    ScheduledLessonPreview(
                        index: titleIndex + 1,
                        title: titles[titleIndex],
                        date: currentDate,
                        weekNumber: weekNum,
                        dayNumber: dayNum
                    )
                )
                titleIndex += 1
            }

            if titleIndex < titles.count {
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
            }
        }

        return previews
    }
}
