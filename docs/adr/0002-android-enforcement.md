# ADR-0002 — Android enforcement and consumer feasibility

Status: Official-documentation assessment complete and feasibility spike authorized **2026-09-05**.
Physical feasibility, Play approval and production acceptance remain **UNSPECIFIED**.
Production enforcement gate: CLOSED. KR-003 is the bounded feasibility issue.

Implementation evidence status: the isolated least-privilege harness and physical protocol now exist under
[`spikes/android-enforcement`](../../spikes/android-enforcement/README.md). A build is not physical evidence; no support boundary or
production decision changes until [KR-003's protocol](../test-plans/KR-003-PHYSICAL.md) is completed.

Current Mi 8 candidate: Q2 and Q3 **physically failed designated Settings/recovery**, and Q4 physically rejected `NEW_TASK | CLEAR_TOP`.
The final bounded Q5 `NEW_TASK | CLEAR_TASK` candidate then [passed one focused recovery calibration](../test-plans/evidence/KR-003-Q5-RECOVERY-2026-09-06.md)
on the exact Mi 8/APK hash. It may enter a separately packaged fresh qualification preflight, but has zero qualification samples. No safe-surface
requirement, broader device/lifecycle gate, support boundary, production acceptance or Play approval is waived.
[Q6](../test-plans/KR-003-Q6-QUALIFICATION.md) was packaged but never run. OD-29 supersedes it with
[Q7](../test-plans/KR-003-Q7-AUTOMATED-QUALIFICATION.md): the exact Q5 candidate plus a new independent fixture oracle, 100 unattended cycles and
at most three human checkpoint sessions. Three Q7 preflight attempts stopped INVALID before ARM/sample 1. Shell input and the separate
[UiAutomation transport](../test-plans/evidence/KR-003-UIAUTOMATION-DENIAL-2026-09-06.md) were denied. Q7 qualification has zero samples;
the bounded [Monkey transport also returned DOWN SECURITY_EXCEPTION](../test-plans/evidence/KR-003-MONKEY-DENIAL-2026-09-07.md).
Q7 is blocked on the unchanged Mi 8 configuration. Under OD-31, shell transport passed on the exact Samsung SM-X400 / Android 16 API 36 / build
`BP4A.251205.006` configuration. Three v1 calibration attempts remain INVALID: runner AppOps verification passed, but its secure-settings
Accessibility check disagreed with healthy candidate/service telemetry. The fresh [runner-v2 calibration](../test-plans/evidence/KR-003-SAMSUNG-HOST-EXCEPTION-2026-09-08.md)
then passed semantic permission verification and the independent positive fixture control, but stopped `INVALID:HOST_EXCEPTION` in the ARM
host stage before any blocked hold. Its discarded exception class/cause remains **UNSPECIFIED**. The runner-v3 host was then invoked once but
failed on its `$script:Host` automatic-variable collision before output creation or any device command. The immutable
[runner-v4 replacement](../test-plans/evidence/KR-003-SAMSUNG-CALIBRATION-V4-BUNDLE-2026-09-08.md) renamed that state and was subsequently invoked
four times. Every [typed v4 record](../test-plans/evidence/KR-003-SAMSUNG-RUNNER-V4-HOST-EXCEPTIONS-2026-09-08.md) passed permission/positive controls,
issued ARM and then stopped before attachment/hold because `$script:Armed` overwrote the same-scope `$armed` reply. Verified cleanup succeeded.
Runner v5 removes that unused alias and validates the scalar ARM reply without changing candidate or gate semantics. The fresh
[runner-v5 calibration](../test-plans/evidence/KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md) then passed one excluded active-oracle expiry:
revision 23 attached in 127 ms, the independent fixture received none of 20 blocked taps and did not regain focus across 22,371 ms, the owner
explicitly agreed with the continuous visible restriction, and CLEAR was verified. This establishes only the calibration prerequisite on that
exact configuration. It is not the required 100-cycle offline p95 result, safety/lifecycle support or a transferable device guarantee.
The first [configuration-bound qualification attempt](../test-plans/evidence/KR-003-SAMSUNG-QUALIFICATION-NETWORK-INVALID-2026-09-09.md) then
stopped `INVALID:ADB_REJECTED` in mobile-data isolation after the Wi-Fi disable/readback boundary and before ARM or cycle 1. The v8 runner had
mistaken a parseable global `mobile_data` setting for proof of telephony capability and discarded the exact operation exit/stderr. Runner-v9
instead probes Android's declared Wi-Fi and telephony-data system features, skips absent paths as `NOT_APPLICABLE`, and preserves the disable,
readback, restoration and fail-closed requirements for every present path. Its physical [runner-v9 execution](../test-plans/evidence/KR-003-SAMSUNG-QUALIFICATION-SCREEN-INVALID-2026-09-09.md)
then retained 100 automated active-oracle PASS rows with p95 317 ms and checkpoints 1/2 PASS, but stopped `INVALID:SCREEN_OR_KEYGUARD` before
any checkpoint-3 owner response. The approximately five-minute prompt interval and combined eligibility loss do not distinguish display timeout
from keyguard, so the whole run remains non-resumable INVALID. Runner-v10 adds only reversible, verified Android Stay awake while plugged in lab
orchestration and exact-setting restoration. Its subsequent [runner-v10 execution](../test-plans/evidence/KR-003-SAMSUNG-QUALIFICATION-HOME-FAIL-2026-09-09.md)
retained another 100 automated PASS rows at p95 318 ms, checkpoints 1/2 and final visibility PASS, then emitted automated
`FAIL:RESTRICTION_LOST` before a Home response. The trace establishes an out-of-sequence overlay Settings-button action followed by the intended
allowed-safe-surface detach: `restriction=true`, `SAFE_SYSTEM`, no fixture focus/input leak. No system Home action or ordinary-app escape is
established. Runner-v11 adds only read-only coarse current navigation-mode capture, mode-specific Home instructions and typed action/result/source
evidence; unknown or an out-of-sequence action stops INVALID. It does not change navigation mode, candidate enforcement or safe-surface semantics.
No formal matrix row, enforcement support boundary or production result advances.

- **Goal:** Identify an honest, testable consumer enforcement mechanism and its unsupported boundary.
- **Context:** Native child must restrict permitted use at zero offline, with p95 ≤ 2 s on supported healthy devices.
- **Constraints:** No stealth, content inspection, security-control circumvention, managed provisioning disguised as normal QR pairing, or unbreakable claims.
- **Done when:** Four options are compared; physical test evidence and policy assessment support an explicit go/no-go.

## Current documentation tension

Android's current Accessibility guide says “Only build an accessibility service if you are creating a general-purpose assistive tool.”
KidRemote is not a disability assistive tool. Play separately permits other declared Accessibility uses with disclosure/consent
and contains a parent-authorized exception concerning disable/uninstall prevention. These statements do not prove KidRemote will be accepted.
The guide/policy tension is a release blocker for the consumer candidate pending explicit policy review and concrete implementation evidence.
[Android Accessibility guide](https://developer.android.com/guide/topics/ui/accessibility/service),
[Play sensitive API policy](https://support.google.com/googleplay/android-developer/answer/16558241),
[Play Accessibility declaration](https://support.google.com/googleplay/android-developer/answer/10964491).

Deterministic parent-defined rules are distinguished from prohibited autonomous planning/action in current Play guidance.
Do not designate KidRemote as isAccessibilityTool=true. This architecture contains no AI child-monitoring or autonomous decision engine.
[Accessibility use policy](https://support.google.com/googleplay/android-developer/answer/10964491).

## Alternatives evaluated

### A — Consumer UsageStats + minimal Accessibility adapter

**Actual capability:** UsageStats measures/reconstructs eligible screen/keyguard transitions; it does not block.
An enabled system-bound AccessibilityService can observe narrowly selected window transitions and display an app-owned accessibility overlay or invoke documented global navigation actions.
A prototype must establish whether ordinary use can be covered and redirected without reading content or impairing essential system UI.
This is an app-layer restriction, not OS package suspension or a system PIN.
[UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager),
[AccessibilityService reference](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService).

**Setup/consent:** install child, pair visibly, give separate explanation/affirmative consent, manually enable Usage Access and Accessibility in Settings.
Never auto-enable, mislabel, or suppress platform warnings. Sideloading/restricted settings must be tested.
**Versions:** candidate API 28+ for screen/keyguard usage events; current target/compile SDK **UNSPECIFIED**.
Test oldest candidate, Android 15/16, and current Android 17 where available; use published platform changes, not stale SDK assumptions.
[Usage events](https://developer.android.com/reference/android/app/usage/UsageEvents.Event),
[Android 17 changes](https://developer.android.com/about/versions/17/), reviewed 2026-09-08.
**Play:** declaration, dedicated disclosure and demo video, listing explanation, least-privilege rationale; approval **UNSPECIFIED**.
**Disable/uninstall resistance:** no guaranteed resistance; user/system can remove privileges or stop the app.
Do not build uninstall interception in MVP; the policy exception does not supply an OS capability or approve circumvention.
**Reboot:** local policy survives; before first unlock, credential-encrypted data and UsageStats availability constrain recovery.
No guaranteed continuous coverage of the boot/unlock window. Test restart and offline reboot explicitly.
**OEM:** background killing/service reconnect/overlay behaviour vary; supported-model list **UNSPECIFIED**.
**Bypasses:** permission revoke, force-stop, uninstall/data clear, safe mode, alternate user, ADB/root; system surfaces may escape overlay.
**Test plan:** matrix PERM/TAMP/TIMER, no package content retrieval, overlay across launcher/fullscreen/split-screen/PiP/recents,
TalkBack/IME/system dialogs/dialler/emergency behaviour, 100 expiry samples per supported model and battery measurement.

## B — Legacy Device Admin

**Actual capability:** approved admin using force-lock can invoke lockNow; this invokes keyguard and the user can unlock with strong authentication.
It is not a persistent screen-time ban and provides no general “remote unlock the child's PIN” operation.
Do not copy old resetPassword recommendations to simulate control.
Some admin policies were deprecated from Android 9, restricted on Android 10, and reset-password behaviour further restricted on Android 11.
[DPM lockNow](https://developer.android.com/reference/android/app/admin/DevicePolicyManager#lockNow()),
[deprecation](https://developers.google.com/android/work/device-admin-deprecation).
**Setup/consent:** explicit admin activation, alarming privileges if over-requested.
**Play:** sensitive permissions/data/purpose rules still apply; no inherited Accessibility approval.
**Disable/uninstall:** admin deactivation adds friction, not a durable anti-tamper guarantee.
**Reboot:** active admin configuration is OS-managed, but local timer restart remains app work.
**OEM/versions:** test each needed policy; do not assume all Device Admin features were deprecated.
**Bypasses:** child PIN, removal/deactivation, safe mode/recovery/root depending device.
**Test plan:** demonstrate PIN unlock defeats a one-time lock; admin removal and offline reboot; verify no wipe/password-control permissions.
**Conclusion:** not sufficient for MVP enforcement; no additional admin permission unless a justified separate capability is approved.

## C — Device Owner / Device Policy Controller

**Actual capability:** managed-device policies can restrict apps/users/settings and prevent uninstall for permitted targets.
Privileges depend on device-owner/profile-owner role and API; a work profile does not control an entire consumer personal profile.
[DPC](https://developer.android.com/work/dpc/build-dpc),
[DPM](https://developer.android.com/reference/android/app/admin/DevicePolicyManager).
**Setup:** managed provisioning during supported device setup, often a fresh/factory-reset device; ordinary in-app pairing cannot promote an installed app to device owner.
Exact consumer distribution/provisioning route is **UNSPECIFIED**; must be verified for target devices.
[Dedicated-device provisioning](https://developer.android.com/work/dpc/dedicated-devices).
**Versions/consent:** managed provisioning and owner role are explicit; policies differ by Android/version/device.
**Play:** enterprise APIs/distribution are not an automatic consumer-store exemption; owner/business eligibility must be reviewed.
**Disable/uninstall resistance:** materially stronger OS policy inside managed boundary; still not root/bootloader/recovery-proof.
**Reboot:** persistent OS restrictions can continue, but accounting/clock/domain restore still needs testing.
**OEM:** device management support and permitted policies vary.
**Bypasses:** physical recovery/factory reset, unlocked bootloader/root, misprovisioned user/profile.
**Test plan:** fresh authorized lab device, owner-role verification, uninstall/user/time restrictions, offline reboot, parent recovery and safe deprovisioning.
**Conclusion:** fallback only after owner explicitly changes setup/product promise; not the consumer MVP by stealth.

## D — Lock Task / kiosk

**Actual capability:** a DPC allowlists packages for managed lock-task operation and can constrain system UI.
Unmanaged screen pinning is user-exitable and is not equivalent.
[Lock Task](https://developer.android.com/work/dpc/dedicated-devices/lock-task-mode).
**Setup/consent:** managed DPC provisioning for robust control; allowlist and escape/deprovision flow.
**Versions:** API-specific lock-task features require capability checks.
**Play:** kiosk capability supplies no exemption from applicable store, permission or audience policies.
**Disable/uninstall:** stronger only inside correctly managed configuration; plain fullscreen/pinning offers little resistance.
**Reboot:** DPC policy may persist; re-entry/launcher and timer state require explicit device tests.
**OEM:** dedicated-device integrations/system UI may differ.
**Bypasses:** pinning exit, management misconfiguration, recovery/root, unsafe broad allowlist.
**Test plan:** verify managed allowlist vs ordinary pinning, emergency/recovery route, reboot, user switching, OEM launcher interaction.
**Conclusion:** appropriate for dedicated appliances, not the stated general consumer-install flow.

## Runtime decision

Recommend testing A first in an isolated native spike. Host live timer callbacks in the already system-bound AccessibilityService while connected;
screen/keyguard receivers resample current state and a serialized reducer performs accounting.
Android's background-service limits distinguish bound services; this is not proof of permanent process survival.
[Background limits](https://developer.android.com/about/versions/oreo/background).

No perpetual dataSync foreground service, fake media playback, or exact-alarm countdown.
If evidence establishes a separate visible foreground service is necessary, evaluate the documented specialUse declaration and review requirements;
it is not an automatic approval or immortality mechanism.
[FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types),
[background start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).
WorkManager is recovery/sync only; periodic work is inexact and minimum 15 minutes.
[Work requests](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).

## Security/privacy implications

No accessibility node/text traversal, screenshots, gestures, credential reading or full event subscriptions.
Start with canRetrieveWindowContent=false and no gesture capability; identify required event types in the spike.
Only ephemeral package identity if indispensable for safe system-surface handling; never retain/upload a package history.
Keep emergency/system accessibility available; an opaque full-screen overlay is not acceptable if it traps the user.

## Operational implications and decision

Support only physically validated OS/model configurations with user-visible health prerequisites.
Ship independent child updates and protocol compatibility floor; provider/OEM regressions can revoke support.
The backend cannot distinguish “offline” from disabled/uninstalled when the child cannot report.
Policy acceptance and safe observed behaviour remain external evidence gates.

## Reasons, risks and tests that invalidate the decision

A best matches consumer setup but has the highest reliability/policy uncertainty.
Invalidate A if it requires prohibited content access or circumvention, fails safe emergency/accessibility behaviour,
cannot recover normal process death/reboot within the declared support envelope, fails p95 expiry latency,
has unacceptable battery cost, or is rejected under applicable policy.
A failure means revise scope/support or ask owner about managed provisioning; never quietly downgrade “enforces” to “shows a reminder.”

## Supported and unsupported threat assumptions

Candidate supported: parent-authorized, unmodified Google-enabled Android, enrolled Android user, intact app storage/permissions,
supported OS/OEM and healthy service, including offline operation after policy receipt.
Unsupported: force-stopped/removed/cleared app; safe mode; other Android users; ADB adversary; root; unlocked bootloader;
OS compromise; physical reset; child holding parent credentials. Exact recovery coverage is **UNSPECIFIED** until measured.
Normal process death/restart, app update and reboot are required tests, not dismissed as adversarial exclusions.
