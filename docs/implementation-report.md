# First native milestone implementation report

Date: 2026-09-20
Branch: `codex/ios-first-milestone`

## Scope delivered

- Native Today, Plan, Records, and Family navigation with empty household setup.
- Student creation; shared course lessons; independent per-student assignments.
- Inclusive eligible-weekday scheduling and flexible undated sequences.
- Assignment state changes with explicit actual completion dates.
- Attendance confirmation with one record per student/day and replacement of daily minutes on correction.
- Retrospective learning recorded separately for each selected student.
- Versioned JSON persistence using atomic writes, input/reference validation, and rejection of corrupt or unsupported records.
- App state is published only after successful save; load errors prevent editing and provide retry.

## Review changes

The integration review found and corrected a missing-file error-code mismatch that blocked fresh households, an unsafe temporary-storage fallback, empty-input and scheduling-overflow edge cases, and non-interactive flexible assignments. Independent tests exercise the first-launch regression and invalid-save preservation.

## Verification

- `sh scripts/test-core.sh`: 18 tests passed, zero failures (13 domain/repository and 5 observable-store tests).
- `sh scripts/build-ios.sh`: Debug iOS Simulator build succeeded for arm64 and x86_64 using Xcode 26.3, with signing disabled.
- Project property-list validation and `git diff --check` passed.
- Independent core review completed; its fresh-install loading finding was fixed and covered by a regression test.
- The simulator acceptance walkthrough, device testing, VoiceOver, Dynamic Type and visual inspection have not been executed. A successful build is not evidence of those checks.

## Limits

This is a first engineering slice, not completion of all roadmap Phase 1 requirements or a production launch. It has not been piloted with families. School-year configuration, learner editing/deletion, full record export, backup/restore UI, grades/credits, transcripts, sophisticated rescheduling/undo, accounts, cloud synchronization, receipts, budgets, and billing remain future work.

The JSON store is single-process and rewrites the complete household. It is not a multi-user database or a backup system. Finalized-record audit history is not implemented. Changing a completion status updates its current state rather than maintaining an event log.

The HTML design prototype is preserved separately and retains its original demo behavior. Do not confuse its simulated features with native application capabilities.
