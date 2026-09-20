# Screen specifications

The prototype is an interactive design study. Its memory-only state is not an application database. Preview and confirmation buttons sometimes demonstrate a flow without executing the full business operation.

## Screen inventory

| # | Screen | Purpose | Current prototype | Production work |
|---|---|---|---|---|
| 01 | Today | Review each child's next work | Child filters, checkboxes, family progress | Stored assignments, correct dates, accessibility and permissions |
| 02 | Weekly plan | Inspect scheduled work | Example week and navigation | Date-aware queries, eligible days, fixed vs flexible assignments |
| 03 | Build lessons | Configure a course sequence | Editable form | Validation, sequence generation from actual entered values |
| 04 | Sequence preview | Review generated assignments | Fixed example sequence | Real preview, saving, sibling/year reuse |
| 05 | Missed-day recovery | Review moves before confirmation | Sample confirmation and undo toggle | Real schedule mutation, exceptions, transaction and guarded undo |
| 06 | Records hub | Navigate to records | Links to record screens | Aggregate real records and school years |
| 07 | Attendance and hours | Review and confirm learning time | Confirmation updates sample totals | Historical edits, time rules, deduplication, export |
| 08 | Grades and report cards | Inspect course performance | Sample averages | Score entry, grading policies, weighting, finalized results |
| 09 | Transcript preview | Review a formal record | Sample document and honest export notice | Actual PDF generation, signature and policy selection, snapshots |
| 10 | Reading log | Track books | Current and finished examples | Add books, update progress, export |
| 11 | Budget and expenses | Understand spending | Totals reflect added demo expenses | Persistence, budget editing, filters, exports |
| 12 | Add expense | Capture a transaction | Validates and stores description/amount/category in memory | Receipt attachment, accurate decimal arithmetic, durable records |
| 13 | Family and pricing | Review household | Sample children and proposed price | Real profiles, memberships, account controls, billing |

## Design language

- Native iOS-style typography, large headings, grouped surfaces, clear bottom navigation.
- Sage is the starting accent, with ocean and plum explored as alternatives in the original inline concept.
- Four app tabs: Today, Plan, Records, Family.
- Parent-facing controls should be distinct from a future limited student experience.
- Prefer concise functional headings for high-frequency screens; decorative headings are exploratory.

## Shared interaction requirements

- Minimum useful touch targets and support for Dynamic Type, VoiceOver, reduced motion, and sufficient contrast.
- Distinguish missing, ungraded, excused, zero, and complete states with labels, not color alone.
- Show empty, loading, validation, offline, failure, and recovery states.
- Do not imply a completed lesson automatically creates a grade or attendance day.
- Show explicit local-save and sync status once persistence is implemented.
- Respect household and student scope on every read, mutation, and export.

## Known prototype limitations

- The full sequence form does not drive the fixed sequence preview.
- Rescheduling is a demonstration toggle; it does not compute future assignment dates.
- Attendance uses illustrative totals and calendar marks, not a validated school calendar.
- Grade and transcript examples are independent fixtures, not linked live records.
- Transcript export displays a notice rather than generating a PDF.
- Expense calculations are illustrative JavaScript arithmetic; production money handling must use decimal values or integer cents.
- Student names and educational examples are fictional. Sample content is not curriculum guidance.
- State resets on reload. There is no backend, authentication, receipt camera flow, or payment processing.
- Optional host-provided design controls may be absent in the standalone export.

## Additional screens required before release

Onboarding/student setup, retrospective learning entry, multi-child activity entry, assignment detail/partial completion, score entry, final grade/credit confirmation, school-calendar settings, data export/recovery, and relevant error/empty states. These are identified requirements, not completed mockups.
