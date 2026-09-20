# ADR 0001: local-first native foundation

Date: 2026-09-20
Status: accepted for the first engineering milestone; subject to revision after family validation.

## Context

The repository has an approved visual baseline but no application implementation. We need a small, testable native workflow that preserves records across launches, without prematurely introducing accounts, cloud services, or a broad database framework.

## Decision

- Use SwiftUI with iOS 17 as the initial deployment target and a Foundation-only `HomeschoolCore` Swift package.
- Keep one local household, no login, and no sample-data insertion on first launch.
- Use versioned Codable JSON behind `SchoolRepository` for this small milestone. Writes validate a candidate snapshot before atomic replacement. The app publishes state only after successful persistence.
- Represent school dates as validated Gregorian `YYYY-MM-DD` civil dates. UI dates convert explicitly at the boundary; dates are not UTC instants.
- Separate courses/lesson definitions from individual student assignments. Multiple students share content but maintain independent completion.
- Require explicit attendance confirmation. Confirming the same student/day replaces the total instructional minutes; it does not add another day or double-count time.
- Retrospective multi-child learning creates separate activity records and does not automatically confirm attendance.
- Use planned, in-progress, completed, and skipped assignment states. Only completed records have actual completion dates; skips do not count as completed learning.
- Defer cloud, record finalization, grades/credits, real PDF exports, billing, and sophisticated rescheduling to subsequent milestones.

## Consequences

The domain is easily unit-tested and remains independent of UI and storage frameworks. JSON is simple to inspect and appropriate for a small single-process household dataset, but saving rewrites the full snapshot. It is not a multi-writer database and should be reevaluated for large datasets or sync. Atomic saving reduces partial-write risk but is not a backup strategy. User-facing backup/restore remains future work; do not imply disaster recovery is implemented.

Corrupt or unsupported data must never cause a silent reset. A load failure places the app in a retryable blocked state. Newer schema versions are rejected until an explicit migration is implemented. Version 1 has no historical migrations to run yet.

Student device access, school-year configuration, permissions, and conflict resolution remain open. This decision does not replace the broader product baseline or claim that Phase 1 is fully complete.
