# GitLab CI testing plan

The current Git remote is GitHub and `.github/workflows/verify.yml` remains the active CI configuration. This document proposes GitLab CI after importing or mirroring the repository into a GitLab project; it does not configure a GitLab project or runner.

## First pipeline

Use a dedicated macOS runner with Xcode 26.3 and the `macos-xcode` tag. The current package imports Apple frameworks (Combine and SwiftUI), so a Linux Swift container cannot run all package tests. Keep `Package.resolved` checked in and enforce its versions. No Supabase credentials or live accounts are needed for unit tests.

Proposed `.gitlab-ci.yml`:

```yaml
stages: [test]

unit_tests:
  stage: test
  tags: [macos-xcode]
  variables:
    DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer
  script:
    - mkdir -p test-results
    - sh scripts/test-core.sh --force-resolved-versions --parallel --num-workers 2 --enable-code-coverage --xunit-output test-results/unit-tests.xml
  artifacts:
    when: always
    expire_in: 7 days
    paths:
      - test-results/
    reports:
      junit: test-results/unit-tests.xml
```

Run on merge requests and default-branch pushes. Add workflow rules to prevent duplicate branch and merge-request pipelines. Require a successful pipeline before merge. The script must preserve Swift's nonzero exit code; uploading a JUnit report alone does not fail a GitLab job. Confirm the generated xUnit XML renders in GitLab's Tests tab on the first run.

## Coverage and next tests

1. **Domain:** run `HomeschoolCoreTests` for scheduling, independent learner progress, attendance replacement, validation, and persistence.
2. **Store:** run `HomeschoolStoreTests` for failed loads/saves, invalid restores, and separate account paths. Add a two-account write/read test and successful restore test.
3. **Auth:** run `HomeschoolAuthTests` using the injected fake driver. Existing cases cover cached-session verification, offline rejection, recovery and confirmation callbacks, hostile links, and sign-out winning a late sign-in response. Extend coverage to signup without a session, failed password updates, recovery refresh/token events, and remote sign-out failure. Keep these deterministic and independent of live Supabase.
4. **Backup service:** extract network orchestration from `AccountView` into an injectable service. Test changed-account responses, corrupt snapshots, denied uploads, and local save failures without network access.

Collect an initial coverage baseline before choosing a threshold. Prioritize branches that grant access or replace records over a single repository-wide percentage. The command above instruments coverage; add an LLVM-to-Cobertura conversion step if GitLab line annotations are desired.

## Separate verification jobs

- Run `sh scripts/build-ios.sh` on macOS alongside unit tests to catch app-only SwiftUI and package integration errors.
- Run `sh scripts/test-ui.sh` on a simulator runner for signed-out navigation, signup validation, existing learning flows, and relaunch persistence. These are UI tests, not unit tests; retain `.xcresult` artifacts.
- Add database integration tests on an isolated local Supabase instance with pinned CLI and Docker versions. Apply all migrations, create disposable users, and assert owner access, cross-user/anonymous denial, immutable snapshots, and malformed payload rejection. Never run destructive fixtures against the live project.
- Run real email-confirmation and password-reset acceptance checks in staging after redirect and email delivery settings are configured. Unit tests do not prove email delivery or hosted Auth settings.

GitLab references: [unit test reports](https://docs.gitlab.com/ci/testing/unit_test_reports/) and [report examples](https://docs.gitlab.com/ci/testing/unit_test_report_examples/).
