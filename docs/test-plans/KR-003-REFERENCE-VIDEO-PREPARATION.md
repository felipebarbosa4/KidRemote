# KR-003 reference/video diagnostic — prerequisite review, 2026-09-10

## Status: not ready for physical publication

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
