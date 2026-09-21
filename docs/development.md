# Native development

## Open and run

Open `HomeSchoolHelper.xcodeproj` in Xcode 26 or newer (the checked-in project uses synchronized source groups). Select the shared `HomeSchoolHelper` scheme and an iPhone simulator, then Run. The deployment target is iOS 17. A physical device requires selecting your own signing team; no signing credentials are committed.

The `HomeschoolCore` package uses Swift tools version 5.9 and can be tested separately from the iOS UI. Full Xcode is required for the native build. If `xcode-select` points to CommandLineTools, the scripts use `/Applications/Xcode.app/Contents/Developer` when installed without changing system settings.

```sh
sh scripts/test-core.sh
sh scripts/build-ios.sh
sh scripts/test-ui.sh
```

The build script uses a generic iOS Simulator destination, disables signing for that build, and writes derived data under ignored `.build/xcode/`. Core tests use unique temporary directories for persistence fixtures; they do not touch the app's household records.

## GitHub verification

The `Verify` GitHub Actions workflow runs on pushes, pull requests and manual dispatch. Independent macOS jobs run domain/store tests, build the iOS Simulator app, and execute XCUITest on iPhone 17 and the smaller iPhone 16e. All select Xcode 26.3 on `macos-15`; the scripts respect an explicit `DEVELOPER_DIR`. Update that version deliberately if the runner image removes it.

No signing credentials or repository write permissions are required. Job timeouts and cancellation of superseded runs limit wasted runner time. GitHub's Actions tab contains results and logs; UI result bundles and screenshots are retained for seven days. These checks do not publish the app. Branch protection is not configured by this workflow; require the tests, build and both UI checks in repository rules to block merges on failures.

## Automated UI coverage

The UI suite creates learners and shared lessons through real forms, verifies independent completion and explicit attendance, corrects attendance without duplicating learner-days, records retrospective learning, and relaunches the app to verify persistence. A second test exercises dark appearance and accessibility-sized text, checks element descriptions and captures each tab. This is limited automated accessibility coverage, not a full VoiceOver or visual-layout certification.

Each test supplies a fresh UUID through the Debug-only `HSH_UI_TEST_ID` environment variable. Storage lives under a separate `HomeSchoolHelperUITests/<UUID>` Application Support directory. Relaunch uses the same ID without resetting data. Tests never delete or overwrite the normal household. Release builds ignore these test settings.

To select another installed simulator, set `HSH_TEST_DESTINATION`, for example `HSH_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16e,OS=latest' sh scripts/test-ui.sh`. Pass `-resultBundlePath .build/my-ui-run.xcresult` to keep a named result bundle; use a new path for each run. Open the bundle in Xcode to inspect failures and attachments.

## Manual acceptance walkthrough

1. Start from the empty household and add two students in Family.
2. Create a course assigned to both students with at least three lessons. Try an undated sequence and a dated sequence with selected weekdays.
3. Open Today, select one student, and mark one lesson completed. Confirm the other student's corresponding lesson remains planned.
4. Change a lesson to in progress or skipped. Neither operation should create attendance.
5. Explicitly confirm attendance for a student/date with instructional minutes. Confirm the same date again and verify the total is replaced, not duplicated.
6. Log retrospective learning for both students and inspect their individual activity records.
7. Terminate and relaunch the app. Students, assignments, statuses, attendance, and activities should remain.
8. Exercise invalid input and, using a disposable development container, unreadable/unsupported JSON. The UI must report the load error and block edits rather than replacing data.

This checklist is a test plan. Only checks recorded in the implementation report should be treated as executed.

## Local data

The app stores one household snapshot in its Application Support container. It has no account, backend, analytics, cloud sync, billing, or automatic sample seed. JSON atomic writes are not a backup system. Uninstalling the app can remove its container; backup/export UI is a follow-up requirement.

## Boundaries

- Business rules: `Sources/HomeschoolCore/`
- Native presentation and observable store: `iOS/HomeSchoolHelper/`
- Independent core tests: `Tests/HomeschoolCoreTests/`
- Store failure and recovery tests: `Tests/HomeschoolStoreTests/`
- Shared API and semantics: [implementation-contract.md](implementation-contract.md)
- Design and future scope: existing product, architecture, and roadmap documents.
