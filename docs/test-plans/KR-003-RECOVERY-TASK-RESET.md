# KR-003 Q5 bounded Settings task-reset calibration

- **Goal:** Determine whether starting `ACTION_SETTINGS` as the root of a cleared associated Settings task provides persistent designated recovery after the known-blocked Digital Wellbeing route.
- **Context:** Q4 proved that `NEW_TASK | CLEAR_TOP` reached Settings for only 681 ms before the prior ordinary surface returned and enforcement reattached on the Mi 8.
- **Constraints:** Same authorized Mi 8 and four isolated phases; no safe allowlist, identity collection, grace period, parallel task, qualification, network mutation, destructive device action or KR-004.
- **Done when:** One immutable Q5 build records expiry, root access, the expected blocked destination, exactly one task-reset recovery attempt, at least ten seconds of physical recovery observation, stable software post-state and verified lab CLEAR.

Protocol: **`KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION`**. Runner version 5 is diagnostic-only and cannot enter the 100-sample loop.

## Evidence-driven decision

### Alternatives evaluated

| Alternative | Decision | Reason |
| --- | --- | --- |
| Keep or retry `NEW_TASK | CLEAR_TOP` | Rejected | Q4 physically failed the exact route; rerunning it cannot turn the failed candidate into an untested one. |
| Add Xiaomi, Settings or Digital Wellbeing identities to the safe allowlist | Rejected | Package provenance does not prove every surface safe and could expose ordinary use. The trace intentionally has no raw identity. |
| Add a timed safe/recovery grace period | Rejected | The previously exposed ordinary destination could remain usable during the grace window. |
| Use `NEW_TASK | MULTIPLE_TASK` or document-task flags | Rejected | Android warns against `MULTIPLE_TASK` unless implementing a top-level launcher and it can create parallel task/Recents state. |
| Launch a narrower permission/settings page | Rejected for this test | It would lower the repository's current designated Settings recovery requirement rather than test it. |
| Collect package/component/task history | Rejected | Q4 already establishes the transition pattern. More identity data would not make recovery safe and exceeds the current privacy contract. |
| `NEW_TASK | CLEAR_TASK` with the same `ACTION_SETTINGS` | Selected as a final bounded flag-only candidate | Android specifies that the associated existing task is cleared before launch and the activity becomes the root of an otherwise empty task. This directly tests whether retained task state causes Q4's return. |

Android documents `ACTION_SETTINGS` as the system-settings action. It documents `FLAG_ACTIVITY_CLEAR_TASK`, usable only with `NEW_TASK`, as
finishing the old activities in the associated task and making the launched activity the new root. This does not clear application data or
change a device setting, but it can discard in-progress navigation within the Settings task. That operational cost is accepted only for this
explicitly selected recovery action and only as a feasibility candidate.
[Settings API](https://developer.android.com/reference/android/provider/Settings#ACTION_SETTINGS),
[Intent flag API](https://developer.android.com/reference/android/content/Intent#FLAG_ACTIVITY_CLEAR_TASK), reviewed 2026-09-06.

### Security and privacy implications

The action, surface classifier, Accessibility event subscription and safe identities do not change. No permission, node/text/content access,
screenshot, gesture, package/component output, task history, account/device identifier or network path is added. `MULTIPLE_TASK`, `CLEAR_TOP`
and time-based exemption are absent. Existing debug trace/probe/receiver isolation and the release DEX/manifest audit remain mandatory.

### Operational implications and risk

The launched Settings task loses its prior activity stack. Persistent system-setting values are not deliberately modified, but any transient
in-progress Settings navigation can be abandoned. MIUI may ignore, redirect or later supersede the standard task semantics; Q5 therefore needs
physical evidence and cannot generalize beyond the exact device. A successful root does not make the Digital Wellbeing destination safe.

This is the last flag-only candidate in KR-003. If one click again produces transient/absent Settings, do not add more flags or silently weaken
SAFE-02. Return the consumer Accessibility approach to architecture/go-no-go review and evaluate a purpose-built recovery activity or a managed
device boundary as a separately recorded decision.

## Hardened evidence oracle

Q4 exposed a tooling-semantic weakness: `FRESH_SAFE_TRANSITION_CORROBORATED` remained latched even after a later ordinary transition. Q5 keeps
the original Q4 evidence unchanged but updates the pure phase reducer:

- safe transition/removal followed by a later `ORDINARY_APP` transition plus overlay reattachment becomes
  `RECOVERY_REGRESSED_TO_ORDINARY`;
- the expected Digital Wellbeing physical `FAIL` is a test precondition, not the overall recovery verdict;
- overall success requires root physical PASS/corroboration, Digital Wellbeing physical FAIL/ordinary corroboration, recovery physical PASS with
  no regression, and a safe automated post-state;
- any physical recovery FAIL remains a physical failure; software never overrides or manufactures the owner's observation.

## Owner sequence and outcome contract

The immutable bundle verifies and installs exact hashes, runs one fresh ten-second expiry, then:

1. report whether restriction remains continuously visible for ten seconds;
2. tap **Open device settings** once and report whether top-level Settings is usable;
3. tap **Digital Wellbeing & parental controls** exactly once; report `F` when enforcement returns, or `I` if uncertain;
4. tap the newly shown **Open device settings** button exactly once; do not tap it again;
5. watch the top-level Settings surface continuously for at least ten seconds and report `P` only if it remains usable;
6. allow post-state capture and automatic sample-preserving lab CLEAR.

Q5 route PASS requires the physical results `PASS / FAIL / PASS` for root, destination and recovery, phase-local software corroboration, no later
ordinary transition/attachment, a final safe state and verified bailout. Any Settings flash followed by restriction, inability to regain Settings,
ordinary destination usability, multiple recovery dispatches, trace/health failure or physical FAIL rejects the candidate. `I`, a missed view,
an extra tap or an unavailable overlay makes the case invalid; the runner never silently retries it. Every result contains zero qualification rows.

## Physical result

The owner executed the immutable Q5 bundle on the authorized Mi 8. [The preserved result](evidence/KR-003-Q5-RECOVERY-2026-09-06.md) is
`DIAGNOSTIC_COMPLETED_ONLY:PHYSICAL_PASS_RECORDED`: expiry PASS, root Settings PASS, expected Digital Wellbeing FAIL, recovery PASS, stable safe
post-state and verified sample-preserving lab CLEAR. One recovery dispatch became safe after 180 ms and remained safe/detached for more than 30
seconds of software sampling; the owner observed at least the required ten seconds. Q5 contributes zero qualification samples.

This proves the focused route only on Xiaomi Mi 8 / MIUI Global 12.0.3 / Android 10 API 29 and APK
`5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`. Exact MIUI task mechanics and broader safe-surface coverage remain
**UNSPECIFIED**. A separately immutable qualification bundle using this exact APK may proceed to its own fresh preflight; KR-003 remains open.
