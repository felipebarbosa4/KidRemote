# KR-003 reference/video diagnostic — executable contract and prerequisite history

## Current implementation (prospective; physical execution NOT RUN)

`Start-KR003-ReferenceVideo.ps1` reuses the existing configuration/APK, permissions, heartbeat, health, disposable timer, independent fixture/input/focus, CLEAR and stay-awake functions. Candidate/enforcement code is unchanged. No installation, network/navigation/credential change, physical-device call by the agent, historical reclassification, resume, pooling, qualification or KR-004 work is authorized.

The diagnostic is characterization, **not a visual calibration PASS or checkpoint substitution**: `CheckpointReplacementAuthorized=false`, `QualificationRows=0`, `Time04Rows=0`, `MatrixContribution=NONE`. Every old immutable bundle stays unchanged; `0596173` stays exploratory-only.

### Owner session and local artifacts

Keep USB/charging connected and the exact authorized Samsung unlocked; leave its existing privileges enabled. Before starting, ensure `C:\platform-tools\kr003-reference-video` is owner-local and excluded from all synchronization/backup upload services. The program rejects other roots and reparse points, but cannot discover every third-party sync policy. Do not send media or the run directory to the assistant, GitHub or CI.

The native Windows entrypoint checks FFmpeg/ffprobe application availability, exact immutable APK hashes/configuration, independent ordinary input and device `screenrecord --help`. Capture capability is then tested by the actual bounded recordings; advertised help alone is not a capture PASS. No dependencies are installed. An unsupported decoder option, inaccessible recorder identity, blank/protected capture or unsupported orientation fails closed.

1. Record a separate six-second ordinary reference through `screenrecord`; decode once into native RGB24. An owner-local WinForms viewer shows the selected decoded frame. Compare it with the actual tablet and press **P in the console only if it matches the ordinary fixture**, otherwise I/Q. No candidate telemetry can approve this reference.
2. Establish one excluded ten-second timer expiry, record a separate six-second restricted reference, and show its decoded frame locally. Press **P only if it matches the actual KidRemote restriction currently displayed**, otherwise I/Q. Each confirmation window is bounded to two minutes. These are the only two reference confirmations.
3. Freeze hashes/provenance before a new held-out recording. CLEAR and independently restore fixture input; record ordinary → a fresh excluded ten-second expiry → at least ten seconds of existing blocked-input/focus checks → CLEAR → independently verified ordinary focus/input. The held-out recording is bounded to 120 seconds. Stop only the recorder PID created by this run, after exact command/path identity verification; verify termination and copied-file hash.
4. Decode the held-out video once, evaluate every decoded frame, preserve original PTS/time base, report native intervals and observed label transitions. Analyze only owner-local media; no pixels, thumbnails, OCR, raw recorder/decoder output or image-bearing derivatives enter the sanitized result.
5. Independently attempt CLEAR, recorder finalization and exact stay-awake restoration even after failure. Retain all failed/partial files. The primary FAIL/INVALID is not overwritten by cleanup failure.

### Recognition rule and validated envelope

References and evaluation share **native dimensions, rotation zero/no autorotation, RGB24, explicit BT.709 limited-range → full-range interpretation**, without scaling, cropping or masks. Captured color metadata is recorded; this is a fixed interpretation, not a claim that Samsung metadata/colorimetry is known. A changed probe configuration is INVALID. Separately recorded/decoded references are approved by the owner, then frozen by reference-manifest hash, individual raw/view/source-video hashes, profile hash, exact device/APK identities and confirmation times. References never adapt to held-out content.

`LOCAL_TILE_MAE_RGB24_V1` computes the **maximum** mean absolute RGB-channel difference over overlapping 16×16 tiles, stride 8, including edge tiles. A frame matches exactly one independently confirmed reference only when every tile is within **2/255 channel levels**. Both/neither matches is UNKNOWN. This local criterion avoids a whole-frame average hiding the tested localized defect; it does not claim sensitivity to every single-pixel or low-contrast change.

Separate synthetic reference encodes use libx264 CRF 18. Development encodes use CRF 20/24/28: maximum measured tile MAE **0.875**, engineering ceiling `ceil(max × 1.15 + 0.25) = 2`. The pinned comparator is then checked against separate CRF 21/27 correct held-out encodes and CRF 25 negative encodes: unrelated third surface, partially replaced restriction, an 8×8 high-contrast wrong region, ambiguous midpoint, and ordinary imagery evaluated in restriction context. No threshold is fitted from the held-out sequence or the earlier ten UNKNOWN frames. This narrowly tested synthetic envelope does **not** establish Samsung encoder compatibility, all surface variants, or detection of arbitrarily small visual defects.

Exact dedup remains SHA-256 lookup **plus decoded-byte equality**. Four bounded in-memory entries cache image labels/distances only, within one invocation bound to fixed references/profile/layout. Every frame retains its index, PTS, hash, integrity, context and verdict; eviction affects cost only. Recognition calls, cache hits, total decode/compare time and distinct pixel hashes are reported from actual material, with no assumed video speedup.

**Known ordinary-surface variation:** the existing fixture updates its visible synthetic tap counter on successful input (`FixtureActivity.kt`). Later correctly functioning ordinary frames therefore need not match the frozen ordinary reference within this narrow envelope. Those frames remain UNKNOWN and the visual result INVALID; no text-region mask, self-fitting or wider threshold is silently introduced. The recording and measurements are still retained for local characterization. This artifact is not a promise of a passing comparator on the current fixture, and it does not bypass the independent input control to keep the image unchanged.

### Timing, result scope and unknowns

FFmpeg uses `-copyts`, `-fps_mode passthrough`, `-enc_time_base demux`; `showinfo` supplies original integer PTS/time base alongside the one raw-RGB decode. Frame count, index, layout and increasing timestamps must agree. There is no nominal-FPS resampling, interpolation or duplication. Native gaps/span are measurements, not continuously observed time.

Recorder launch/verified-termination host monotonic timestamps provide independently journaled outer bounds. They do **not** establish a PTS-to-host anchor. Consequently every physical frame remains `UNASSIGNED`, `PhaseSpecificVisualVerdict=INVALID_ALIGNMENT_UNVERIFIED`, with alignment uncertainty null/UNSPECIFIED. The runner never aligns phases from PTS zero or an assumed successful expiry. A complete recognized ordinary → restricted → ordinary sequence with independent controls and cleanup may return `CHARACTERIZED:COMPLETED_NO_CHECKPOINT_AUTHORIZATION`, never a phase-specific PASS. Unknown imagery, missing transitions, decode/capture errors or uncertain controls are INVALID. An independently established enforcement/input failure remains FAIL. Without alignment, a visual timing disagreement alone is not promoted to an enforcement FAIL.

Physical capture interference, Samsung codec compatibility, static-channel freshness, representation of physical display frames and interruption sensitivity remain **UNSPECIFIED**. No shortest guaranteed detectable physical interruption or accepted missed-interruption duration is claimed. The smallest subsequent sensitivity test is a separately controlled known-surface interruption with independently bracketed times, chosen after measured gaps/alignment are available, including both detected and missed cases. No Home exercisability, physical Home action, OD-39 Path-B observation or Settings/recovery safety gate is replaced.

### Cleanup, retention and bailout

Estimated owner session: **3–6 minutes plus local analysis**, up to two minutes per confirmation and a 180-second decoder limit per clip; not a measured Samsung duration. Press **Q in the console** to stop through finalization. During decoding, the standalone `Clear-KR003-ReferenceVideo.ps1 -RunDirectory <exact printed directory>` creates a cancellation request and waits for the main process's exclusive lock before touching the device. If the main process is still finalizing after 30 seconds it reports INVALID and makes no competing device mutation; wait for exit before invoking bailout again. It never kills an unrelated process or overwrites the primary summary.

CLEAR must verify unarmed/unrestricted/unattached, healthy candidate and ordinary fixture focus/input; exact original stay-awake restoration is read back. No network restoration is necessary because no network mutation occurs. Recorder termination and copy status are independent. An inaccessible/mismatched PID is never killed. Media remains on device under the **exact run-generated paths in `recorders.json`** and locally under `local-media`; device-file removal remains an explicit owner cleanup requirement after review, not an automatic deletion. Preserve failed/invalid/partial recordings and journals until the owner explicitly chooses disposition. No uninstall or clear-data.

### Validation record

Native Windows PowerShell 5.1 / FFmpeg 8.1.2-full_build-www.gyan.dev actually executed the synthetic codec comparator, including separate development and held-out encodes, exact cached/uncached equivalence, cancellation and truncated input. Orchestration tests inject enrollment rejection, capture timeout, cancellation, decoder/partial-copy failure and cleanup failure while preserving primary results. Fake-executable tests exercise the real entrypoint, standalone bailout and exact owned-recorder command/termination behavior. Native PowerShell 7 is exercised by required CI; codec tests explicitly report SKIP if FFmpeg is unavailable there, separately from the executed local codec test. Android source is unchanged; required CI still runs JVM/build/lint/release isolation, without a redundant manual Android rebuild.

Capture basis: [Android screenrecord documentation](https://developer.android.com/tools/adb#screenrecord), [AOSP owned recorder signal handling](https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/cmds/screenrecord/screenrecord.cpp), and [FFmpeg showinfo](https://ffmpeg.org/ffmpeg-filters.html#showinfo), checked 2026-09-10. These APIs do not guarantee complete physical-display observation.

## Historical prerequisite review (preserved; superseded implementation status below)

### Status at prerequisite review: not ready for physical publication

The requested one-session diagnostic is **not implemented end-to-end and no new bundle is published**. The safe review/prototype source `b1c4a1b262d595feaba1d068db7500d5b7eca9f5` was pushed over verified remote baseline `630eaad4cfa84d40aedf8ead6f93c593f1c212c3`. [CI 34521866149](https://github.com/felipebarbosa4/KidRemote/actions/runs/34521866149) passed Linux validation, native Windows PowerShell 5.1/7 and required Android build/lint/release isolation. No manual unchanged Android build was repeated.

Preparation checked host dependencies and added pure reference-provenance/timestamp validators plus a synthetic codec prerequisite test. It did not integrate a viewer, device recorder, streaming physical analyzer or cleanup orchestration. No physical command is supplied for unfinished code. Every old bundle, physical verdict and qualification count remains unchanged; `0596173` is still exploratory-only. KR-004 is untouched.

## Observed prerequisite result

Windows has FFmpeg and ffprobe **8.1.2-full_build-www.gyan.dev**, discovered through `Get-Command`, with no installation, administrator action, WSLInterop repair or ADB invocation. Local PowerShell 7 remains absent; the required native PS7 checks ran successfully in CI.

The synthetic test authored a 64×64 PNG reference, froze it, encoded a separate ten-frame static sequence using libx264 / YUV420P / CRF 23, then decoded the video **once**. FFmpeg's tee output produced decoded RGBA pixels for exact comparison and framehash metadata with original integer PTS. No image/content was emitted to tools, stored in the repository, or uploaded. The temporary synthetic-only files were removed after the test; no physical evidence was deleted.

| Sanitized measurement | Result |
| --- | --- |
| Frames decoded | 10 |
| Exact decoded matches to the independent PNG | 0 |
| UNKNOWN under exact-reference recognition | 10 |
| Differing channel comparisons across all frames | 80,470 |
| Held-out decode passes | 1 |
| Native output time base | 1/10240 |
| Retained integer PTS | 0, 2048, 4096, 6144, 8192, 10240, 12288, 14336, 16384, 18432 |
| PTS interval / first-to-last span | 200 ms / 1,800 ms |
| Host-phase alignment / physical sensitivity | UNSPECIFIED / UNSPECIFIED |

**OBSERVED:** the correct synthetic surface is rejected by the available exact-reference recognizer after this lossy encode/decode. **INFERRED:** simply approving an uncompressed screenshot and matching video pixels exactly is not a reliable enrollment design. **UNSPECIFIED:** Samsung encoder behavior, actual color conversion, rate/cadence, reference repeatability and physical capture interference; this test is not Samsung evidence and does not establish that every encoding changes every frame.

This does not disprove content-hash deduplication, which remains exact and separately tested. No dedup optimization or new runtime benchmark was performed. A new similarity threshold would need its own negative validation and must not be invented to turn these UNKNOWN results into restriction recognition. The reference/codec mismatch is distinct from the still-unapproved interruption tolerance.

## Proposed single-session contract (not executable yet)

Exact binding remains `samsung / SM-X400 / Android 16 / API 36 / BP4A.251205.006 / 2026-07-05`, with the already calibrated candidate and independent fixture APK hashes. No network/navigation/credential changes.

1. Reuse configuration/APK, permission, heartbeat, health, fixture/input/focus and reversible stay-awake preflight. Future owner-operated checks must verify device `screenrecord` support, bounded completion, local storage, capture protection and decoder availability before relying on capture. Never bypass secure layers.
2. In one owner-local setup, capture the ordinary fixture and an excluded restriction reference. Present each through an explicitly local viewer, not assistant tools, web viewers or uploads. Ask only: “This local reference matches the ordinary fixture actually displayed” and “This local reference matches the actual KidRemote restriction displayed.” Any missing/uncertain confirmation is INVALID. Candidate attachment is not a confirmation.
3. Bind each reference's content hash, capture configuration, classifier/reference version, exact device configuration and APK versions to its recorded owner confirmation/time. Freeze both before a distinct held-out ordinary → fresh restriction → ordinary sequence. The new metadata validator rejects missing confirmation, configuration/APK mismatch and references frozen at/after held-out start. It is not yet a file-integrity enrollment implementation.
4. Prefer one bounded `screenrecord` MPEG-4 for the held-out sequence, reusing the existing ten-second independent blocked-input/focus checks and final CLEAR/ordinary-use verification. The reference acquisition must first be validated against the chosen decoding/color pipeline; two approvals alone cannot calibrate codec variation.
5. Decode once through existing FFmpeg tooling. Preserve original PTS/time base; no nominal-FPS resampling, frame interpolation or duplication. Hash decoded pixels, confirm exact equality before reusing image labels, and evaluate each frame's phase/integrity/timing independently. Unknown surfaces stay UNKNOWN/INVALID. No label is fitted or updated from the held-out sequence.
6. Report interval distribution, maximum observed interval, span, transition observations, actual decoder/cache counts and measured processing duration. Retain `HostAlignmentUncertaintyMillis=null` when no independent clock anchor is established; do not invent phase assignments from a video starting at PTS zero. The validator preserves native timestamps and refuses non-increasing values; it does not establish a clock anchor.
7. Always use `CheckpointReplacementAuthorized=false`, zero qualification/TIME-04 rows and no matrix contribution. Static capture freshness and physical interruption sensitivity remain UNSPECIFIED unless separately tested. A completed characterization with unknown recognition/alignment must not be presented as a calibrated visual PASS.

Estimated target duration after implementation: roughly 3–5 minutes plus the two brief owner confirmations; this is a design estimate, not a measured run time. No owner execution is requested now.

## Capture/decoder basis

Android documents `screenrecord` as MPEG-4 display capture with a bounded time limit and device/resolution/rotation limitations; it does not guarantee representation of every physical display frame. [Android ADB documentation](https://developer.android.com/tools/adb#screenrecord).

FFmpeg documents passthrough timestamp mode and encoder time-base selection, plus tee and framehash muxers. The synthetic test uses `-copyts`, `-fps_mode passthrough`, `-enc_time_base demux` and a single rawvideo/tee output to preserve decoded-packet timestamps alongside pixels. These flags do not supply the missing offset to the host's monotonic oracle journal. [FFmpeg timestamp options](https://ffmpeg.org/ffmpeg-all.html#Advanced-options), [tee and framehash](https://ffmpeg.org/ffmpeg-formats.html). Official documentation checked 2026-09-10.

## Cleanup and retention contract

Future diagnostic finalization must call the existing CLEAR/bailout and restore exact stay-awake state even on enrollment, capture, decoder or reference failure; preserve the primary FAIL/INVALID. Verify unarmed/unrestricted/unattached state, healthy candidate and ordinary fixture focus/input return. No network restoration is needed because no network mutation is permitted. The bounded recorder must finish or be specifically stopped and its completion state retained before owner handoff. No uninstall or clear-data.

References, recordings and image-bearing derivatives must stay in a dedicated owner-controlled non-cloud directory outside the repository. Preserve all physical FAIL/INVALID artifacts until disposition; no automatic deletion or replacement. Capture process/device-file cleanup and the owner-facing standalone bailout must be validated before any bundle is published. Existing cleanup tests remain passing, but they do not verify an unimplemented video finalizer.

## Smallest unresolved implementation step

First test **separately acquired references through the same intended codec/color pipeline** against an independent held-out encode, including wrong surfaces and small genuine changes. Do not enroll from or adapt to the held-out recording. If exact recognition is still unsuitable, propose and negatively validate a reference comparison rule before physical handoff; keep unknowns fail-closed. Separately implement/validate host-to-video clock alignment or explicitly produce unassigned/INVALID phase verdicts while characterizing.

After measured physical cadence is available, the smallest sensitivity experiment is a short, controlled known-surface interruption test with independently bracketed transitions and durations chosen around the measured gaps/alignment uncertainty. It must test both detected and missed interruptions; none of those durations is an acceptance tolerance without an explicit decision. No human visual or Home/safety checkpoint can currently be replaced.
