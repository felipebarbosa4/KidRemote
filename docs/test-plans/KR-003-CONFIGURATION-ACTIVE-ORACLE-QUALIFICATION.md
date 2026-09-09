# KR-003 configuration-bound active-oracle qualification

- **Goal:** Measure 100 fresh offline expiry cycles on exactly one calibration-approved Android configuration using the independent fixture oracle and no more than three owner checkpoint sessions.
- **Context:** The generic transport and standalone oracle calibration are separate prerequisites. A passing calibration permits bundle preparation but contributes no qualification row.
- **Constraints:** Exact manifest-bound metadata and APK hashes; owner-operated authorized lab device; no pooling/resume, screenshots, UI nodes/text/content, package history, serial, permission grant, uninstall, data clear, reboot, production move or cross-device inference.
- **Done when:** One new run contains an excluded passing preflight, exactly 100 consecutive active-oracle rows, three passing checkpoint sessions, offline confirmation, nearest-rank p95 at most 2,000 ms, complete metric agreement, verified CLEAR/bailout and verified radio restoration.

Protocol: **`KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION`**, runner version 11.

## Configuration and provenance gate

The immutable bundle records one captured manufacturer, model, Android release, API, security patch and build ID. The runner reads those fields again and stops `INVALID:DEVICE_CONFIGURATION_CHANGED` before changing radios or starting its excluded preflight if any field differs. Owner-provided product/software labels remain a separate manifest object and are not represented as captured system metadata.

The bundle also records the strict-ingested calibration directory, result, source commit, summary/device hashes, referenced transport-device hash and exact candidate/fixture hashes. Bundle construction rejects any non-PASS calibration, nonzero qualification count, missing owner agreement, failed cleanup/finalization, metadata drift or APK drift.

## Evidence model

The runner preserves the approved Q7 evidence model:

1. Verify bundle and installed/pulled APK hashes; capture only minimized device/configuration fields.
2. Verify candidate Usage Access and Accessibility independently through typed runner parsing, plus fresh heartbeat, healthy candidate and eligibility. Unknown fails closed. Read the current-user Android navigation-mode setting into only `THREE_BUTTON`, `TWO_BUTTON`, `GESTURE` or `UNKNOWN`; UNKNOWN stops before qualification. Recheck permissions before and after every expiry; revocation after initial success is a failure.
3. Query the declared `android.hardware.wifi` and `android.hardware.telephony.data` features, journal state only for present transports, reversibly disable enabled transports, require owner offline confirmation, and verify restoration during finalization. Absent transports are `NOT_APPLICABLE`; unknown capability/state fails closed. Radio flags do not prove absence of every possible network path.
4. Run one excluded active-oracle preflight expiry and obtain the first physical agreement checkpoint.
5. CLEAR and require the same tap to reach the independent fixture; obtain the second physical negative-control checkpoint.
6. Reset metrics, then run attempts 1–100 unattended. Each fresh revision requires a per-cycle positive control, attachment, a minimum ten-second blocked hold, 20 denied input taps, zero focus regain, stable fixture identity/coordinate, fresh/continuous candidate state and one paired latency.
7. After attempt 100, retain one final visible persistence and guided Home/Settings/recovery/re-entry session. The Home instruction is selected from the coarse current navigation mode: tap the on-screen Home control for button modes or swipe up once from the bottom edge for gesture mode. The owner must not use the overlay Settings control until the recovery phase. Retain Home action exercised/resisted, exercised/escaped, or not-exercisable/unknown separately, followed by automated CLEAR/input verification.
8. Independently recalculate p50/p95/max, compare all 100 candidate samples, verify radio restoration and finalization, and stop.

The fixture is a separate package/UID with no candidate callback, shared storage or network permission. Candidate telemetry is corroborating only. No test reads or stores Accessibility node text, screenshots, content, accounts, serials or package history.

## Owner interaction and duration

Begin with the device unlocked, interactive and connected to external power and the owner-controlled Windows host. The runner temporarily enables Android's Stay awake while plugged in setting, retains only the original/applied integer and coarse power-source class, verifies both throughout unattended cycles, and restores/verifies the exact original setting in finalization. It does not remove or weaken PIN/pattern/password security. Unknown state, unplugging, enable/readback failure or restoration failure is INVALID. The owner interacts only:

1. At the initial preflight session: confirm the runner-established offline state, watch the excluded ten-second restricted hold and answer the continuous-block prompt, then confirm the controlled CLEAR/tap is visibly ordinary.
2. During attempts 1–100: no interaction or confirmation is required; do not use the device. The measured runner-v9 section took approximately 60 minutes; allow approximately 60–70 minutes.
3. At the post-run session: watch the held restriction for ten seconds, perform the displayed current-mode system Home action exactly once, then complete only the separately prompted root Settings, Digital Wellbeing, overlay recovery and ordinary re-entry checks before automated CLEAR. Do not tap **Open device settings** during the Home prompt. If the Home action is unavailable or uncertain, answer `I`; the run stops INVALID.

Total elapsed time is expected to be approximately 75–90 minutes depending on setup and owner response time.

## Verdicts and stopping rules

- **PASS:** exactly 100 consecutive qualification rows pass both active oracles, all three checkpoint records pass, offline mode is confirmed, p95 is at most 2,000 ms, aggregate metrics agree, final CLEAR/bailout and radio restoration are verified, and finalization has no error. The name is `PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY`.
- **FAIL:** a physical failure, an exercised Home action that escapes, missing/lost restriction on an ordinary surface, input delivery or focus regain while blocked, service/permission loss after initial establishment, unsafe recovery result, metric corruption, p95 above 2,000 ms, or failed required cleanup/restoration.
- **INVALID:** configuration/hash/provenance mismatch, unknown/unparseable permission, navigation mode or oracle state, Home action not exercisable/unknown, an out-of-sequence Settings action during the Home phase, broken positive control, stale/ambiguous reply, interrupted eligibility, host/evidence uncertainty, owner `I`, or incomplete/faulted finalization.

Any FAIL, INVALID, or owner stop preserves the current attempt and terminates the run. It is never replaced, resumed or pooled. The standalone CLEAR helper changes only the disposable lab timer and verifies that latency samples are preserved; it is not consumer recovery evidence. If normal finalization cannot verify network restoration, preserve the run directory and use its minimized `network-original.json` record for owner-assisted restoration.

The runner retains `network-capabilities.json` and `network-operations.json` with typed feature presence, operation/phase/result, exit code and coarse stderr class only. It never persists raw `pm`, `settings` or `svc` output. An absent `pm has-feature` result is the documented `false`/exit-1 outcome, not an ADB rejection. A present Wi-Fi or mobile-data path keeps the same disable, readback and restoration gate; airplane mode is not substituted.

## Interpretation

A PASS advances only the exact bound configuration under this evidence model. It is 100 automated active-oracle cycles plus three physical checkpoint sessions, never 100 human-visible confirmations. Other devices/builds, lifecycle/tamper/safe-surface rows, Play approval and production readiness remain separate gates.
