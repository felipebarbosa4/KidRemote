# KR-008 local accounting lab

- **Goal:** Exercise the local reducer and real child Room persistence under OD-46.
- **Context:** Stacked on KR-007 `4537954`; KR-003 remains open. Canonical policy and trusted UTC inputs are local fixtures.
- **Constraints:** Task-owned emulator only. No network sync, receipts, enforcement, physical device, package history or distribution.
- **Done when:** Focused domain, SQLite migration/crash/failure and emulator tests have explicit results; physical and KR-009 gaps remain open.

The child `accounting` package accepts an existing identity-bound epoch, canonical absolute policy and monotonic samples. Initialization writes a marker into the existing encrypted identity before creating the ledger. A missing/corrupt database cannot reset an initialized allowance. Room commits the aggregate, version and coverage cursor together, with no destructive migration fallback. The v1→v2 migration is a synthetic local schema fixture, not evidence of a shipped app update. Only current/previous day aggregates are retained, inside `noBackupFilesDir`; no separate credential is created.

The pure reducer projects UTC from a supplied trusted UTC/elapsed anchor in the fixed household zone. Device wall clock and default zone are not inputs. Boot mismatch retains the old balance/day and requires clock recovery. The approved AC-7 extension accepts bound canonical trusted-time fixtures for newer-period recovery; it does not obtain or authenticate network time. Signals settle the prior interval; disagreement between elapsed and uptime makes coverage uncertain. This intentionally conservative check can degrade on sampling jitter; actual signal accuracy and battery cost are unverified.

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

## Versioned APK update slice

`build-update.mjs` retains the normal v2 debug APK/test APK, builds v1 with `-Pkr008UpdateVersion=1` in the same CI signing environment and verifies package/version/certificate/hash identities. It restores the normal v2 debug artifact after packaging the pair. No signing key is published. Both apps share the unchanged production accounting implementation; the legacy schema is an explicit local SQL fixture, not a historical released APK.

Place the `kr008-update-apks` CI bundle in `apks-kr008-update-<source-prefix7>` within the existing owner directory. Run `update-runtime.mjs` with `KR006_RUNTIME_DIRECTORY` and full `KR008_UPDATE_SOURCE`. Each independent scenario may initialize clean synthetic test packages before preparing state. Between prepare, versioned replacement and final verification it never clears data or uninstalls. It retains enumerated results in a unique `kr008-update-*.json`, then clears test data and requires the owned emulator to be stopped separately. Migration interruption and expected downgrade refusal remain individually classified. See [app-update evidence](../../docs/test-plans/evidence/KR-008-UPDATE-2026-09-13.md).

## Approved AC-7 recovery slice

Complete suffix coverage is validated before any aggregate mutation. `recoveryThrough` prevents a shorter replay from hiding a previously observed gap; `observedBoot` rejects stale boot anchors. The payload codec reads legacy format 1 and writes format 2, without changing SQL schema/migration. Legacy uncertain payloads have no trustworthy gap endpoint and require newer-period recovery B. The existing Room revision plus a minimal checksummed `AtomicFile` write intent distinguishes rollback from a complete commit interrupted before intent cleanup. Storage health alone never clears uncertainty. Facade instances are serialized in the existing single child process; this is not a multi-process database protocol. No raw policy, credential or history is added to intent/evidence.

Put matching APKs in `apks-kr008-recovery` inside the owned directory and run `recovery-runtime.mjs` with the same environment as the core runner. Nine ordered stages include seven normal tests and two deliberate process kills around the actual recovery transaction. Each attempt is retained separately, with enumerated results only. Core and app-update runners remain focused regressions of this shared persistence change. No physical UsageStats coverage or network trusted-time evidence follows from fixtures.

Platform references reviewed for this slice: [AtomicFile](https://developer.android.com/reference/android/util/AtomicFile) requires caller serialization; [Room transactions](https://developer.android.com/reference/androidx/room/RoomDatabase) commit a callable only when it completes without exception. The facade uses one process-wide lock, explicit intent-file sync/read verification and the existing Room transaction. These are implementation assumptions tested with process death, not physical power-loss acceptance.

[Approved recovery results and independently retained runtime attempts](../../docs/test-plans/evidence/KR-008-RECOVERY-2026-09-13.md) include the final code/source CI and core/update regressions. Local AC-7 is demonstrated; physical acceptance and KR-009 remain open.
