# KR-008 local accounting lab

- **Goal:** Exercise the local reducer and real child Room persistence under OD-46.
- **Context:** Stacked on KR-007 `4537954`; KR-003 remains open. Canonical policy and trusted UTC inputs are local fixtures.
- **Constraints:** Task-owned emulator only. No network sync, receipts, enforcement, physical device, package history or distribution.
- **Done when:** Focused domain, SQLite migration/crash/failure and emulator tests have explicit results; physical and KR-009 gaps remain open.

The child `accounting` package accepts an existing identity-bound epoch, canonical absolute policy and monotonic samples. Initialization writes a marker into the existing encrypted identity before creating the ledger. A missing/corrupt database cannot reset an initialized allowance. Room commits the aggregate, version and coverage cursor together, with no destructive migration fallback. The v1→v2 migration is a synthetic local schema fixture, not evidence of a shipped app update. Only current/previous day aggregates are retained, inside `noBackupFilesDir`; no separate credential is created.

The pure reducer projects UTC from a supplied trusted UTC/elapsed anchor in the fixed household zone. Device wall clock and default zone are not inputs. Boot mismatch retains the old balance/day and requires clock recovery. No trusted re-anchor/recovery flow is implemented here. Signals settle the prior interval; disagreement between elapsed and uptime makes coverage uncertain. This intentionally conservative check can degrade on sampling jitter; actual signal accuracy and battery cost are unverified.

A new engine instance requires recovery before reporting known accounting. Reconciliation accepts independently established monotonic signal ranges and consumes only their uncovered suffix. The debug-only UsageStats probe retains no package fields and never certifies complete coverage merely from query results. Missing/truncated/ambiguous coverage leaves accounting degraded. Fixtures supply proven coverage; they are not physical UsageStats evidence. Android does not guarantee full retained history: [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager). Clock semantics: [SystemClock](https://developer.android.com/reference/android/os/SystemClock), [BOOT_COUNT](https://developer.android.com/reference/android/provider/Settings.Global#BOOT_COUNT). Adopted persistence: [Room 2.8.5](https://developer.android.com/jetpack/androidx/releases/room).

`restrictionRequired` is desired local state only. There is no service, enforcement adapter, timer scheduling, permission onboarding, network sync or healthy/enforced UI claim. The unconfigured enrollment app does not start this engine automatically. Validated KR-007 removal clears the ledger before clearing identity; expiry alone never deletes accounting. Emergency/recovery enforcement and receipts remain outside this local slice.

## Verification

Run `node --test tools/kr008/*.test.mjs`, repository validation, and the parent Gradle build (includes child unit tests, lint, debug/instrumentation and release). Required CI also runs existing SQL/HTTP/RLS regressions; those are not a new accounting backend.

For runtime, place the matching CI child debug and instrumentation APKs in `apks-kr008-accounting` inside the existing owner-manifest task directory. Start that owned emulator using `tools/kr006/windows-emulator.ps1`, then run:

```sh
KR006_RUNTIME_DIRECTORY=/mnt/c/Users/3feli/AppData/Local/KidRemote/kr006-runtime/e03b4820-193b-4132-b1fc-f7950eeed7fe \
KR008_APK_SOURCE=<source-commit> node tools/kr008/android-runtime.mjs
```

The runner verifies AVD identity/API, targets only emulator-5584, installs only child test packages and emits aggregate result codes and APK hashes. Tests run in a deliberate order: restart and crash survivors depend on prior committed fixtures. Two kills are expected only with a matching durable marker plus instrumentation process-crash result; other failures remain failures. Each attempt gets a separate JSON report. Cleanup clears the exact task packages; stop the owned emulator afterwards. No logcat, screenshot, physical discovery or Usage Access grant is used.
