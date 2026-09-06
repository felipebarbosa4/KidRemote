# KR-003 Q4 bounded recovery-launch calibration

- **Goal:** Determine whether bringing the existing Settings root to the front with `NEW_TASK | CLEAR_TOP` makes designated recovery persistent after the known-failed Digital Wellbeing route.
- **Context:** [Q3](evidence/KR-003-Q3-RECOVERY-2026-09-06.md) proved that Digital Wellbeing is treated as ORDINARY_APP and that `NEW_TASK` alone produced transient or absent later recovery.
- **Constraints:** Same authorized Mi 8 and four-phase diagnostic; no allowlist, identity collection, qualification, network mutation, destructive action or KR-004.
- **Done when:** One owner-run calibration records expiry, Settings root, Digital Wellbeing, exactly one recovery attempt, post-state and verified lab CLEAR.

Protocol: **`KR003-Q4-RECOVERY-REPAIR-CALIBRATION`**. This bundle is diagnostic-only and cannot enter the 100-sample loop.

Executed result: **failed** on the authorized Mi 8. [Q4 evidence](evidence/KR-003-Q4-RECOVERY-2026-09-06.md) records one dispatch reaching a safe
surface transiently, followed 681 ms later by `ORDINARY_APP` and overlay reattachment. The physical recovery result was FAIL. This candidate is
rejected for the tested route and must not be rerun as if untested.

## Bounded change

The Settings button continues to launch `Settings.ACTION_SETTINGS`. It now adds `FLAG_ACTIVITY_CLEAR_TOP` to the required
`FLAG_ACTIVITY_NEW_TASK`. Android documents that `NEW_TASK` can restore an existing task's last state; with `CLEAR_TOP`, the system locates the
target activity and removes activities above it in that task so it can handle the new intent. This is a candidate repair, not proof that MIUI's
cross-package/task behaviour will comply. [Official task/back-stack guidance](https://developer.android.com/guide/components/activities/tasks-and-back-stack#IntentFlags), reviewed 2026-09-06.

Alternatives evaluated:

- add the Digital Wellbeing or Xiaomi package to the safe allowlist: rejected; Q3 did not capture identity and package membership does not prove every surface safe;
- add a time-based safe grace period: rejected; an ordinary app could become usable during the grace period;
- use `CLEAR_TASK` or `MULTIPLE_TASK`: rejected for this first repair because they are broader than needed and may discard or create task state;
- collect package/component/task history: rejected; unnecessary for testing the documented root-restoration semantics and outside the privacy contract;
- `NEW_TASK | CLEAR_TOP`: selected as the smallest standard task-navigation change addressing Q3's transient return.

Security/privacy implications: no new permission, Accessibility event, node/text/content access, package output, screenshot, history, identifier or
network path. The safe-package policy and UNKNOWN fail-open semantics do not change. Operationally, Settings activities above its root may lose
in-progress navigation state when recovery is requested; no Settings values or app data are cleared. This trade-off is acceptable only for a
user-initiated emergency/recovery action and remains subject to physical usability testing.

Risks/tests that invalidate the decision: MIUI ignores or redirects the root intent; an external destination task immediately returns; Settings
values/navigation are unexpectedly lost beyond the current task stack; one click produces multiple handler activations; the safe root is still
transient; an ordinary app becomes safe; release diagnostics leak. Any expiry flicker, destination becoming ordinary-usable, unusable recovery,
second button activation, missing phase evidence or failed bailout stops this calibration. A successful Mi 8 result does not generalize to other
Xiaomi/MIUI/Android/OEM configurations.

## Owner sequence

The immutable bundle verifies/install hashes, runs one fresh ten-second expiry and then uses the same non-overlapping phases as Q3:

1. confirm the restriction remains continuously visible for ten seconds;
2. tap **Open device settings** once and confirm top-level Settings is usable;
3. tap **Digital Wellbeing & parental controls** once and report whether enforcement returns;
4. if blocked, tap **Open device settings** exactly once, do not tap it again, and watch top-level Settings for at least ten seconds before reporting whether it remains usable;
5. allow the runner to capture post-state and execute its sample-preserving lab CLEAR.

Physical P/F/I values remain independent from software evidence. Digital Wellbeing being blocked is expected and is not itself a repair failure;
the repair succeeds for this route only if the **single** recovery action restores continuously usable top-level Settings for the observation
period with a fresh phase-local safe transition and no reattachment. CLEAR is cleanup, never consumer recovery evidence. Zero qualification rows
are produced under every outcome.
