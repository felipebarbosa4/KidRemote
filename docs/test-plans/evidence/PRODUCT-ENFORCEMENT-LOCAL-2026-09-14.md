# OD-49 product enforcement integration — local evidence

- **Goal:** Existing KR-003 candidate → child ledger → observed ACK/status, Issues #3/#10.
- **Context:** Baseline e007eb23331d5b1cc924f9b67ab9fb0329e39414, draft PR #24 stacked on unchanged PR #23.
- **Constraints:** Existing emulator-5584 only; no physical commands/capture, FCM, deployment, distribution or merge. Historical evidence/verdicts unchanged.
- **Done when:** Local implementation and tests are classified honestly; remaining local/physical gaps and independent attempts are preserved.

## Implementation

**OBSERVED source:** OD-49 recorded before implementation. Reused SurfacePolicy and
SurfaceEventResolver unchanged, TYPE_ACCESSIBILITY_OVERLAY geometry/flags and Q5
NEW_TASK|CLEAR_TASK Settings route. Spike sources remain unchanged. Excluded lab
countdown/store, device-protected preferences, ARM/CLEAR/debug receivers, traces,
latency counters, diagnostic UsageStats, visual code and all qualification data.

One EnforcementAdapter consumes the identity-bound Room state. Consent, existing
Usage Access and service readiness gate requests. Screen/keyguard/monotonic sampling
runs in the connected service; no backend clock or foreground service was added.
The blocked measurement signal stops consumption while the view remains attached
without latching desired restriction after Unlock. Existing A/B recovery remains
unchanged; no missing interval is forgiven.

Observed attachment requires Android isAttachedToWindow + isShown, separate from
addView returning and from policy persistence. Safe/unknown surfaces and lifecycle
failure do not claim applied. Detach failure retains the reference and reports
failure. Removal is validated by the existing identity contract; no automatic new
identity is created. Credential/network expiry does not erase the downloaded ledger.

The latest bounded observation persists in the same Room row alongside the immutable
pending ACK. Payload format 5 reads formats 1–4; the extra blocked signal and one
512-character observation add no event/package history. Old observations are never
restored as current application proof. Server ACK validates own device/epoch,
canonical aggregates, sequence/version and health/boolean consistency. Parent applied
status now requires the matching observed transition, not admission or persistence.
An authenticated device report is not independent hardware attestation.

Android attachment callbacks and the bound service API were checked against
[View.OnAttachStateChangeListener](https://developer.android.com/reference/android/view/View.OnAttachStateChangeListener)
and [AccessibilityService](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService).
These APIs do not establish physical visibility, input resistance or safe recovery.

## Actual results and source boundaries

**OBSERVED:** local build/lint debug/release and instrumentation APK compilation PASS;
84 child JVM + 14 parent JVM tests PASS. Legacy codec fixtures are independent old
layouts; versions 1–4 retain state. 99 affected Node tests PASS. Parent/child packaged
permission, backup and release-isolation audits PASS. No new uses-permission was
added: release retains the previous Usage Access setup boundary and cannot be
represented as qualified or ready for distribution.

**OBSERVED SQL/HTTP:** 574 PostgreSQL assertions (558 regressions + 16 observed-report
assertions); 91 sync HTTP assertions including 100 intentional retries of one
operation, plus 10 parent projection assertions. Existing regressions: 44 real Auth,
38 enrollment/removal, 27 rotation, 28 pairing protocol assertions (gateway storage
stub for that pairing suite, real SQL separately). Own-device observed restriction,
detachment, retry identity, incompatible health denial, disconnect downgrade and
superseded status are covered. No deployed Edge/provider evidence is claimed.

**OBSERVED Android service:** final source 84a85a57c8a14cc8dea1264eee643519436609a1,
owned API-36 emulator, actual service/window manager and existing ordinary fixture.
Sixteen typed checkpoints passed: connection; Lock attachment; offline observation
persistence; positive Unlock detach; zero attach; Unlock-at-zero remains required;
+600 clears expiry; absolute +1800 then manual Lock remains attached; stale Unlock;
safe surface detach; ordinary reentry; disconnect; reconnect; restored offline
restriction; ledger/uncertainty retention; validated-removal clear. Time/policy inputs
in this test are canonical local fixtures, including explicitly trusted recovery B,
not fabricated authenticated network evidence. Settings/AppOps changes were limited
to the owned emulator; the final host verifies restoration by readback.

**OBSERVED authenticated vertical slice:** two independent runs passed, including
final source 84a85a5: actual parent JWT operation LOCK → PostgreSQL desired state →
loopback gateway device sync → child Room → actual Accessibility overlay observation
→ durable ACK → own parent status read returns applied. Eleven instrumented typed
checkpoints passed in each run. Later local removal in the test is a validated fixture,
not a claimed remotely authenticated revocation. Backend and test-data cleanup passed.

The ordinary fixture is used as a known separate app surface. These tests observe
Android attachment/detachment; they do not run the KR-003 independent tap/focus oracle,
human visibility checkpoints, emergency tests or physical p95 qualification.

## Independent failed/partial attempts

- Initial local script used unavailable `python`; no implementation script executed until rerun with python3.
- Build 01 failed on recursive Kotlin inference for the shared engine; explicit type fixed it. Builds 02–06 passed.
- Node 01: 95/97 passed; two historical blanket Accessibility prohibitions failed. Replaced only that prohibition with explicit system-binding/content-blind checks under OD-49. Node final: 99/99.
- Backend 01 passed old regressions. Backend 02 stopped after assertion 7 of the new suite: unscoped scalar test query found multiple fixture devices (SQLSTATE 21000). Scoped test queries; backend 03 and both chain runs passed 574 assertions.
- Android attempts 01/02 connected but neither Home attempt observed attachment; the second recorded UNKNOWN_SURFACE_FAIL_OPEN. The exact window-event sequence is UNSPECIFIED. No attachment PASS claimed.
- Android 03 observed attachment but latest observation could not persist behind an older pending ACK. Added one bounded observation in Room, preserving immutable retry semantics.
- Build 07: 78/80 JVM passed; two legacy fixtures incorrectly trimmed the changed encoder. Replaced those constructions with explicit frozen legacy layouts; no decoding validation was loosened.
- Android 04 passed through reconnect but remained unknown on the already-foreground app. A real safe→ordinary window transition was required; the unknown interval is not relabeled protected.
- Subsequent service attempts passed, including final signal-separated implementation. Each JSON and APK manifest remains independent in the adjacent directory.
- CI 34845720664 (5aee7ab) was cancelled after trailing-EOF-whitespace failures in validate and the KR-004 precheck (not a database-test failure); 34846118855 and 34846300458 were superseded/cancelled. These runs are not counted as successful CI. Final CI status is recorded in the PR/issue handoff.

## Remaining boundaries / physical handoff

**INFERRED:** ordinary reentry can restore the persisted requirement after the service
reconnects. **UNSPECIFIED:** coverage before a new trustworthy window transition,
physical input denial/visibility, automatic post-death service recovery, emergency/
accessibility/Settings safety, OEM lifecycle, UsageStats accuracy, battery/write cost
and physical enforcement p95. Local service callback observations do not close KR-003,
KR-008 physical acceptance or KR-010 AC-5/6. FCM remains absent.

Exactly one prospective short physical slice was assessed and is **NOT READY**.
Existing Samsung tooling verifies the spike package/hash and ARM/CLEAR protocol; the
product exposes neither lab controller nor transferable service permission. Reusing
that runner by replacing the candidate identity would weaken its oracle. The new
product service requires separate setup, and no product-compatible independent oracle
has been validated under the requested no-settings-change/no-destructive-operation
boundary. No safe exact PowerShell command or duration can therefore be supplied.
No physical command was executed, and no new physical test framework was invented.

## Focused persistence regressions

**OBSERVED source 84a85a5:** KR-008 core: eight normal instrumentation methods PASS
plus two expected real process deaths, including migration/refused downgrade,
transaction rollback/commit, storage corruption, identity boundary and uncovered
suffix. Recovery A/B: seven normal methods PASS plus two expected real process deaths.
The first recovery attempt retained six successful/expected stages, then
killAfterRecoveryCommit returned host exit 1 without a status code: cause
**UNSPECIFIED**. It remains NOT_PASSED in its own JSON; no acceptance criterion was
weakened. The independent fresh run passed all nine stages and verified cleanup.

## Final service source and retained restart gap

**OBSERVED source 0406a92e6e3120057d1e9cf975d693af75fcd145:** the standalone actual
service test passed 18 checkpoints. In addition to the earlier 16, child presentation
reads the live ledger without fabricating a facade restart gap, and disconnected
adapter health persists in Room. Validated removal now explicitly verifies that the
actual attached/blocked observation clears. Source a954e51 passed the same 18 before
the additional process-death test methods were introduced.

Two separate process-death attempts (sources 6932790 and 0406a92) are **NOT_PASSED**.
Each reached 13 checkpoints and deliberately killed the child while restricted; the
expected death marker was verified. The next instrumentation process did not observe
a connected service within 15 seconds, including after explicit app reopen in the
second attempt. After the kill, the second host observed packageStopped=false and
serviceStillEnabled=true. Cause is **UNSPECIFIED**: these results do not distinguish
platform binding delay/failure from instrumentation interference. No automatic
post-death restoration PASS is claimed, and no permission toggle or weaker oracle
was substituted to pass that seam. Settings readback and owned test-data cleanup
were verified independently for both failures. Existing Room/crash and sync/ACK
restart regressions passed, but do not resolve this actual-service lifecycle gap.

**OBSERVED regressions source 84a85a5:** KR-009 passed 22 normal instrumentation
methods plus two expected process deaths, including pagination/retry/lost ACK and
revocation. KR-010 passed all 36 stages using actual parent UI/Auth/HTTP/child Room:
+600/+1800, duplicate/lost-response retry, Lock/Unlock at zero, limit/conflict,
outage/stale presentation, emulator font scaling/keyboard and logout. That existing
UI suite runs with the adapter disabled. The separate authenticated adapter chain
proves the parent HTTP applied projection; it is not a claim that the integrated
applied label was physically observed in Compose or on a physical device.

Final exercised APK manifest: `enforcement-apks-10.json`, source 0406a92 (child v2,
parent v1; local debug signing only). SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| Child | d2b3448b5c5574dc4ec693fc1e09386bae6ca1082e42c8c68f6c8c5d870b7f2f |
| Child instrumentation | 4884df5282bab2567c18176481273f666e5e502113c3c8bc0f20ddc4e1820e33 |
| Parent | bb416b9e5c0d4b2957b2323914527c176ff8249c51282f34d8bb9126401e3354 |
| Parent instrumentation | 82b08632f152ebf87bc910c0925a29d8d4641bdecfd60fe410402fd625461ece |
| Existing ordinary fixture | 223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc |

Main child APK is unchanged between a954e51, 6932790 and 0406a92; the later changes
add only instrumentation/harness diagnostics. Source-specific manifests and every
partial attempt remain adjacent. No raw logs, bearer credentials or window content
are included; local raw-run files are represented only by hashes.

**OBSERVED CI:** run 34847015489 at source 84a85a5 passed all five jobs. The final
reporting-head CI result is recorded separately in PR #24 and Issues #3/#10.

**OBSERVED final authenticated chain source 0406a92:** a third independent run passed
all 12 typed service checkpoints and parent status `applied`, including durable
disconnect observation. The same run again passed 574 SQL, 91 sync HTTP, 10 parent
projection, 44 Auth, 38 enrollment/removal and 27 rotation assertions. Backend secret
scan and scoped container/network/gateway cleanup passed. This is the final exercised
APK source; subsequent reporting changes contain only documentation/evidence.

## Cleanup and handoff state

**OBSERVED:** owned test app data cleared; modified emulator settings restored and
read back; loopback gateway/Auth/PostgreSQL and task network removed. No labeled task
container remains. The guarded owner helper stopped emulator-5584; AVD/APK/evidence
artifacts remain available. No physical ADB, camera/visual qualification, screenshots,
FCM, deployment, distribution or merge was performed.

The prospective physical handoff blocker is traceable to
`tools/kr003/Test-KR003-OracleCalibration.ps1`: fixed spike package/service/receiver,
APK hash verification and independent ARM/CLEAR/fixture agreement. Product attachment
callbacks cannot replace that independent oracle. Automatic post-process-death
service recovery also remains locally unproven. This delivery must remain a draft;
it is not a physical readiness or enforcement acceptance verdict.
