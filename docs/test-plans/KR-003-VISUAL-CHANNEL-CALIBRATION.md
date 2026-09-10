# KR-003 excluded local-only visual-channel calibration

> **Validity correction — 2026-09-10:** [synthetic review](KR-003-VISUAL-VALIDITY-REVIEW.md) reproduces circular restricted-reference acceptance and between-sample blindness. Immutable `0596173` is exploratory only; its PASS cannot authorize any human-checkpoint substitution. Physical execution remains Not run and is not requested. The original sequence and emitted identifiers below are retained for artifact traceability, subject to this scope correction.

- **Goal:** Determine whether a host-captured visual channel can reliably distinguish the known ordinary fixture, the full-screen restriction interval and restored ordinary fixture on one exact authorized Samsung configuration.
- **Context:** OD-41 is a prospective lab evidence exception. This short mechanism test may justify later design work to replace eligible human VISUAL checkpoints, but it is not qualification or TIME-04 evidence.
- **Constraints:** Owner-operated local lab only; exact configuration/APK binding; no network mutation; no candidate APK changes or production capture permission; raw PNGs stay outside the repository/cloud; no OCR, UI nodes/text, accounts, package history or secure-content bypass; no resume/pooling; zero qualification/TIME-04 rows and no matrix contribution.
- **Done when:** One fresh ordinary → expiry/restricted → ordinary sequence produces a typed configuration-specific PASS, FAIL or INVALID with measured sampling bounds, independent fixture agreement and verified cleanup/restoration.

## Approved configuration and tooling

The bundle is bound to captured `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05` and to the already calibrated candidate and fixture hashes. `Galaxy Tab S10 Lite` / `One UI 8.5` remain owner-provided labels.

The host worker uses the documented `adb exec-out screencap -p` path, which streams a PNG to standard output. A PNG sample carries no device display-frame presentation timestamp, so the runner neither invents one nor assigns a nominal frame rate: it preserves each actual host-monotonic capture request start/end interval and reports the full request duration as alignment uncertainty. Android documents that secure windows can produce blank screenshots; blank/protected output is INVALID and the runner does not request or bypass secure-layer capture. See [Android Debug Bridge: take a screenshot](https://developer.android.com/tools/adb#screencap), [FLAG_SECURE](https://developer.android.com/security/fraud-prevention/activities#flag-secure), and the [Android 16 SurfaceFlinger capture path](https://android.googlesource.com/platform/frameworks/native/+/refs/heads/android16-release/services/surfaceflinger/SurfaceFlinger.cpp).

Device-specific preflight requires accepted `screencap -p`, decodable same-dimension PNGs, nonblank output, sufficient measured sampling cadence, exact APK/configuration checks, healthy permission/service state, a ready fixture and reversible verified stay-awake state. None of these properties is inferred from another device.

## Bounded sequence

1. Verify immutable bundle files, exact configuration/APKs, Usage Access, Accessibility, fresh heartbeat, candidate eligibility/health, screen/keyguard eligibility and fixture readiness. Enable and journal only the existing reversible stay-awake mechanism; do not alter network, navigation mode or credentials. Foreground the disposable fixture, then take two capture samples and require accepted, hash-verified, decodable, same-dimension, nonblank PNGs before ARM.
2. Start the local capture worker. With the candidate CLEAR and the ordinary fixture focused/resumed, retain a bounded ordinary reference and require exactly one fixture input increment.
3. ARM one fresh disposable ten-second timer while capture continues. Record the expiry transition and require restriction=true, attached=true, `ORDINARY_APP`, healthy/eligible state and fixture displacement.
4. For at least ten seconds, retain capture samples while the existing independent oracle injects twenty bounded fixture taps and requires continuous candidate restriction/attachment/health, no fixture focus regain/input increment and no service restart.
5. CLEAR, require unarmed/unrestricted/unattached state, return to the same ordinary fixture, require focus/resume and one input increment, and retain a second ordinary reference.
6. Stop capture, analyze locally, restore stay-awake exactly, verify final configuration/APK state, and retain only sanitized classifications/metrics plus the local raw-media retention record.

No owner visual response is requested and no automated visual result is serialized as a human observation.

## Deterministic local classifier

The analyzer decodes each local PNG through Windows `System.Drawing`, downsamples the complete frame to a fixed 24×24 RGB grid in memory and discards the grid after analysis. It derives ordinary and restricted prototypes from the same phase-grouped frames it evaluates. Fixture controls independently establish input/focus effects, not the expected restriction's visual identity. These are implemented benchmark filters, not sufficient independent visual calibration:

- at least three frames in each reference/observation phase;
- at least 10,000 ms restricted-window duration, at least 90% first-to-last sample span and a worst-case sampling gap no greater than 1,500 ms;
- strictly advancing, non-overlapping capture-request intervals;
- nonblank, same-dimension, hash-verified frames;
- repeatable pre/post ordinary references;
- ordinary/restricted separation across at least 5% of the 24×24 tiles with changed-region span at least 50% of width and 30% of height, so a small marker cannot establish the restricted surface;
- every classified frame agreeing with its phase label and sufficient nearest-prototype margin; this self-fitted agreement does not exclude an unrelated third surface.

Identical hashes on a static surface do not imply dropped frames. Advancing requests and endpoint transitions detect some frozen-output cases but cannot distinguish a freeze confined to the restricted phase from legitimate static content. Sample span is not continuously observed time; the 1,500 ms and 90% filters have no recorded owner-approved sensitivity basis. The gap statistic is conditional on freshness, capture/display correspondence and recognition sensitivity, not a guaranteed physical interruption-detection bound. Events wholly between samples or below spatial sensitivity can be missed.

## Verdicts

- **Emitted PASS — `PASSED_VISUAL_CHANNEL_CALIBRATION_THIS_CONFIGURATION_ONLY:ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED`:** self-fitted phase groups separate under benchmark filters, with independent fixture/candidate agreement, completed capture, verified CLEAR/ordinary input and exact stay-awake restoration. This does not recognize the expected restriction independently or prove continuous visibility.
- **Emitted FAIL:** a confidently classified sample disagrees with its phase. Preserve the result, but investigate semantic identity/capture reliability separately before calling a visual-only mismatch an established enforcement failure. Independently established input/focus escape remains enforcement evidence.
- **INVALID:** rejected/empty/blank/protected/undecodable capture; changed dimensions; ambiguous or insufficient surface separation; truncated phases; insufficient cadence/coverage; stale/unverified liveness; unknown permission/health/configuration; uncertain analyzer result; or incomplete cleanup/restoration.

The run always records `QualificationRows=0`, `Time04Rows=0`, `MatrixContribution=NONE` and `HumanObservationSerialized=false`. A stopped attempt is preserved independently and never resumed, replaced or pooled.

## Local-only retention and cleanup

Raw frames live only under `C:\platform-tools\kr003-visual-calibration\visual-<timestamp>-<nonce>\raw-frames`. They are not copied into the bundle or repository and are never emitted as base64, terminal content, CI artifacts, GitHub evidence or assistant/tool images. Sanitized JSON may retain filenames, hashes, dimensions, monotonic intervals, distances, coverage and classifications.

Successful raw media must be retained until strict result ingestion and owner review are complete, then deleted only by an explicit owner action. FAIL/INVALID raw media must be preserved until the root-cause disposition is recorded; no later run replaces it. The runner never deletes raw media automatically. The ordinary timer/device bailout is separate: press `Q` while the runner is active, or run `Clear-KR003-Lab.ps1` from the immutable bundle in another PowerShell window. That helper changes only the disposable timer and preserves all visual/evidence files. If the capture worker remains after an abnormal console termination, close only that bundle-started PowerShell process; retain its completed/partial files for review.

## Prospective checkpoint scope

No PASS from `0596173` justifies checkpoint substitution. A future independent-reference and sensitivity-calibrated design could be evaluated for the normal/post-run visual-persistence portions only, paired with the fixture oracle. It cannot replace:

- OD-39 Path A's actual physical Home action or Path B's owner observation that Home is unavailable;
- confirmation that a Home control/gesture is physically exercisable;
- physical Settings, Digital Wellbeing, emergency/accessibility, recovery, lock/keyguard or other human-operability/safety actions not separately calibrated;
- owner consent, device handling, secure-content observations, policy approval, lifecycle/tamper gates or support-boundary decisions.
