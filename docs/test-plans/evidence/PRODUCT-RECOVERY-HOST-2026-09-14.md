# OD-49 extension — host-observed Accessibility recovery

- **Goal:** Isolate normal product death from instrumentation lifecycle interference, PR #24 / Issues #3/#10.
- **Context:** Reporting baseline fabfbdc; existing two NOT_PASSED attempts remain byte-for-byte unchanged.
- **Constraints:** Existing owned API-36 emulator only; unchanged product APK first. No physical, FCM, permission transfer, new enforcement architecture or production acceptance.
- **Done when:** Independent observations, minimal justified correction, regressions and cleanup are recorded without pooling failed attempts.

## Diagnosis and bounded correction

**OBSERVED:** the first host run used the original APK/self-kill and did not launch
another instrumentation during a 60-second automatic window. No product PID appeared;
the service remained enabled/crashed and package stopped=false. Opening ChildActivity
only after that window created a PID but did not clear the crashed service state.
The initial binding parser was subsequently found invalid (see attempts below), so
its bound=false field is not promoted into independent binding proof.

**INFERRED mechanism, supported by controlled comparison:** Android 16
[ActivityManagerService](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/services/core/java/com/android/server/am/ActivityManagerService.java)
handles an instrumented app death by finishing its instrumentation. Unless mNoRestart
is set, finishInstrumentationLocked invokes forceStopPackageLocked. This internal
cleanup is distinct from a host `am force-stop`, and stopped=false alone does not
prove the service binding survived. The earlier self-kill seam therefore included
instrumentation cleanup, not just normal product process death.

The same platform's [am command](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/cmds/am/src/com/android/commands/am/Am.java)
supports --no-restart. The corrected host starts the app only during initial setup,
then uses this mode for the existing self-kill test. After death, no instrumentation,
app reopen, service toggle, force-stop or clear-data occurs in the automatic window.
A new verification instrumentation is admitted only after the host independently
observes the new PID and system service binding, and also uses --no-restart.

**OBSERVED source boundary:** no product Kotlin, manifest, service XML, SQL or parent
UI changed in this extension. Child APK SHA-256 remains
`d2b3448b5c5574dc4ec693fc1e09386bae6ca1082e42c8c68f6c8c5d870b7f2f`.
Only host/parser/test code, CI parser checks and documentation changed. The new
verifier requires the host-observed PID, same decrypted identity/epoch/version,
unchanged used_ms/bonus/period, required restriction and conservative uncertainty,
a fresh ordinary-surface transition and a durable matching observation. Network
mode sends an actual ACK only after that observation, through existing DeviceSync.

## Independent attempts and time interpretation

The first three diagnostic JSON files preserve observer mistakes, including their
original emitted NO_RECOVERY_OBSERVED labels. They are **INVALID_OBSERVER** for
binding conclusions, not product failures or successful recovery confirmations:

- Observer v1 incorrectly searched for a package name in Bound services. Android 16
  [AbstractAccessibilityServiceConnection.dump](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/services/accessibility/java/com/android/server/accessibility/AbstractAccessibilityServiceConnection.java)
  emits service label/configuration there, without component identity. The second
  run nevertheless retained a new PID and the transition out of crashed state.
- Observer v2 also confused system UID 1000 with its variable PID. A sanitized
  component-scoped read identified system PID 679 and received=true/hasBound=true.
- Observer v3 cross-checks the known metadata label with the exact component's
  ServiceRecord, product PID and received system binding. Its unchanged-APK run
  observed automatic recovery at 4.773 seconds; the original post-death verification
  passed. This diagnostic preceded the stronger identity/durable observation checks.

**OBSERVED confirmations, source 0b1ecdddf5b9843c16de513b1dce7081f6ed58af:** two
independent clean attempts returned PASS_AUTOMATIC_RECOVERY. First matching host
observations were at **4.708 s** and **4.665 s**. Both verified unchanged encrypted
identity bytes, decrypted identity/epoch, policy version, usage/bonus/period,
uncertainty, desired restriction, fresh overlay observation, durable observation and
validated-removal detach. No rows from earlier attempts are pooled into these passes.

These values are host elapsed seconds from the instrumentation command returning
its expected process-death result, not exact OS callback latency from the kill
instruction. Polling and adb/dumpsys round trips bound observation resolution. The
60-second window is diagnostic only, not a new acceptance threshold or physical p95.
The OS binding observation precedes the verifier; starting instrumentation is never
counted as recovery. Offline confirmations run with the existing debug sync-control
fixture and no task backend. Production scheduling, OEM and physical behavior remain
UNSPECIFIED.

## Product-compatible physical oracle assessment

**BLOCKED — assessment only; no physical command or new runner implemented.**
The smallest prospective change is a narrow product control driver around the
existing independent fixture transport, not a replacement oracle:

1. Retain exact APK/source/signer verification and the separate ordinary fixture's
   instance, focus/resume, coordinates and positive input control. Product permission
   must already be independently verified for its exact component; absent setup is
   INVALID, with no settings mutation or permission-transfer assumption.
2. Replace only spike ARM/CLEAR and trace/revision dependencies with authenticated
   canonical product LOCK/UNLOCK, version correlation and existing sync/report paths.
   Reports establish correlation/health, never the independent blocking verdict.
3. Keep fixture input/focus checks as the independent restriction oracle. Final
   unrestricted cleanup requires canonical Unlock with positive remaining and an
   independent successful fixture input/focus control. Uncertain/expired accounting
   cannot be bypassed to manufacture cleanup.
4. Validate transport failures, response loss, version mismatch, fixture restart,
   missing permissions and final cleanup on the emulator before any owner command.

The existing `Test-KR003-OracleCalibration.ps1` combines spike ARM/CLEAR, internal
attachment/trace/latency and permission prompts. Directly swapping its package name
would invalidate those checks. No product driver or its failure/cleanup oracle has
been implemented/validated in this recovery-only scope, and current physical setup
is UNSPECIFIED. Therefore no owner PowerShell command is supplied. No navigation or
security setting, screenshot/capture or physical device was touched.

## Authenticated recovery and focused regressions

**OBSERVED source 0b1ecdd:** the separate real-network run passed automatic binding
at **5.829 s** (same host timing origin). Parent JWT LOCK → actual PostgreSQL/gateway
sync → Room/overlay/ACK preceded the self-kill. The recovery window had no app reopen,
permission toggle or new instrumentation; existing debug sync-control suppresses
scheduled network work. Only after host binding and fresh durable observation did
verification invoke DeviceSync and send the new ACK. Parent status returned applied.
The run passed seven pre-kill and six post-recovery typed checkpoints and verified
backend/owned-data cleanup. This is additional network evidence, not a row pooled
into either of the two standalone confirmations.

The same run passed **574 SQL assertions**, **91 sync HTTP assertions** (100 identical
operation retries), **10 parent projection**, **44 Auth**, **38 enrollment/removal**,
**27 rotation**, and **28 pairing protocol assertions**. Pairing HTTP uses its existing
storage stub; its PostgreSQL coverage is separate. No Edge deployment is claimed.

Standalone service regression passed **18 checkpoints**. KR-008 core passed **8
normal + 2 expected process deaths**; recovery A/B passed **7 + 2**. JVM **84 child +
14 parent**, Node **99**, host observer **3**, debug/release build/lint and packaged
security/privacy audits passed. Final test APK compilation also passed. Product
APK bytes remain unchanged; test APK SHA-256 is
`4e40973e24eca018ac972b22bdca49021d23146bd7c1e4e24dce5a042853a1b2`.
All APK/source/signer identities are in `product-recovery/apks-source-0b1ecdd.json`.

**OBSERVED KR-009 regression:** 22 normal instrumentation methods plus two expected
process deaths passed, including frozen pagination, durable retry, response loss,
WorkManager, auth/revocation and explicit convergence without push. These existing
sync tests intentionally use their original harness semantics; they are not reused
as proof of automatic AccessibilityService recovery.

## Remaining lifecycle boundary

Root-cause classification is **B: instrumentation lifecycle/observation interference**,
with a controlled --no-restart comparison and no identified product lifecycle defect.
The old two NOT_PASSED results retain their original verdicts; this new evidence
addresses their previously unresolved seam without rewriting them.

Automatic rebinding on this emulator does not establish continuous restriction
during process absence or before a new trustworthy ordinary-window transition.
Force-stop recovery, reboot enforcement, physical/OEM scheduling, battery, emergency
safety and physical p95 remain UNSPECIFIED in this slice. No immortality mechanism,
foreground service, boot receiver, permission toggle loop or enforcement timer was
added. The conservative accounting recovery rule is unchanged.


**OBSERVED KR-010 controls:** all 36 actual parent/child/HTTP/Room stages passed,
including +600/+1800, lost response/idempotent retry, Lock/Unlock at zero, conflict,
invalid limit, outage/stale data and logout. Warm list observation was 316 ms on this
emulator, not production performance acceptance. The existing UI regression keeps
the adapter disabled; integrated post-recovery applied status is proven by the
separate authenticated HTTP chain, not a claimed physical UI observation.

## Cleanup and CI reporting

**OBSERVED:** task app/test data cleared; the recovery host restored its emulator
settings and verified readback. Each gateway/Auth/PostgreSQL/network cleanup passed;
no task-labeled container remains. The owner-guarded helper stopped emulator-5584;
ports 5584/5585 and the owned AVD process are absent. APK/AVD/evidence artifacts remain.
No physical command, FCM, capture, deployment, distribution or merge occurred.

Required CI is run on the final reporting head and its exact result is recorded in
PR #24 / Issues #3/#10, avoiding an evidence-only commit cycle after CI. Earlier CI
results remain historical and are not substituted for that final run.
