# KR-003 excluded reference/video bundle — 2026-09-10

## Publication and scope

- Source: `760597e855326393e72bffb242e91d795006b7e9`.
- Immutable owner-local bundle: `C:\platform-tools\kr003-reference-video-bundles\760597e`.
- `bundle.json` SHA-256: `5ba319a38d1fa93f920f30081f77aece8df9c88302ee3c39ce8d51e0f401ad86`.
- Main entrypoint SHA-256: `16faa989e8dd5d57cb74d346a610bdee7b4845ab49936ae52e089f73fa40bb61`.
- Standalone bailout SHA-256: `5e84097075e9bb11f89845831ee3aacb3178e0f57dc851dc88bba1bc0935bc35`.
- Comparator profile SHA-256: `0413aef199f64032963342799c61e81212156f310c84487638cb0df2ea64ef96`.
- Candidate SHA-256: `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`.
- Independent fixture SHA-256: `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`.

The unchanged APKs were copied from hash-verified immutable `80dcdf4`, not rebuilt. All fifteen payload hashes were verified by the actual bundled bailout's pre-device integrity gate using fake ADB. The bundled entrypoint and bailout passed eight native PowerShell 5.1 assertions; reserved-variable/parser checks passed across its ten PowerShell files. No agent ADB/device operation occurred.

Exact authorized configuration: `samsung / SM-X400 / Android 16 / API 36 / BP4A.251205.006 / 2026-07-05`. Owner labels Galaxy Tab S10 Lite / One UI 8.5 are not captured system metadata.

**Physical execution: NOT RUN.** This is an executable **characterization** diagnostic, not a validated visual-channel PASS or human-checkpoint replacement. `CheckpointReplacementAuthorized=false`; qualification rows 0; TIME-04 rows 0; matrix contribution NONE. Historical evidence, OD-39/OD-40, full runner-v12 and KR-004 remain unchanged. Full qualification is not requested.

## Executed verification

[Source CI 34527472825](https://github.com/felipebarbosa4/KidRemote/actions/runs/34527472825) passed all three jobs: Linux repository/Node/PowerShell checks; native Windows PowerShell 5.1 and PowerShell 7.6.5; required Android JVM/build/lint/merged-manifest/release-DEX isolation. No redundant manual unchanged Android build was run.

Local native Windows PowerShell 5.1 with FFmpeg 8.1.2-full_build-www.gyan.dev executed **28 codec/comparator assertions**, including independently encoded held-out surfaces, unrelated/partial/localized/ambiguous negatives, a one-decoded-frame disappearance, a nonzero original PTS offset, cancellation and truncation. Development maximum tile MAE was 0.875; independently pinned engineering ceiling 2. The original dedup benchmark was not repeated.

Native suites also passed: 66 orchestration assertions, 16 recorder/reference-integrity assertions, 8 entrypoint/bailout assertions, 19 provenance/timestamp assertions, 162 qualification assertions and 247 finalization assertions. Node evidence/security tests: 29 passed. Repository validation and diff checks passed.

**Explicit CI skips:** FFmpeg was unavailable on the Windows CI runner. Both engines reported comparator codec SKIP, separately from their successful pure/fake-tool tests. The codec was actually executed locally as stated above; no CI codec execution is claimed. No private or physical media was used, viewed or transmitted.

## One owner-operated command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-reference-video-bundles\760597e\Start-KR003-ReferenceVideo.ps1"
```

Keep USB/charging connected, screen unlocked, required permissions enabled, and FFmpeg/ffprobe available on PATH. Ensure `C:\platform-tools\kr003-reference-video` is outside cloud synchronization. Compare each owner-local viewer image with the actual tablet: first ordinary fixture, then actual restriction; press P in the console only if it matches, otherwise I/Q. No additional human visual/Home verdict is requested. Estimated 3–6 minutes plus local analysis; physical duration is unmeasured.

Press Q in the console for orderly cleanup. For a stuck/cancelled host run, use the dedicated `Clear-KR003-ReferenceVideo.ps1` from this same bundle with `-RunDirectory` set to the exact printed `C:\platform-tools\kr003-reference-video\video-...` directory. It requests cancellation, waits for exclusive ownership, then independently attempts CLEAR, owned recorder finalization and exact stay-awake restoration. It does not kill a competing process or overwrite the primary result. If it reports that the main process is still finalizing, wait for its exit before invoking bailout again.

Retain local media and the exact generated device MP4 paths listed in `recorders.json` until explicit owner disposition. No automatic file deletion, uninstall or clear-data; device media removal remains an owner cleanup requirement. Never upload or attach the run directory, images, frames or videos to the assistant, GitHub or CI.

## Limits requiring attention before interpreting a result

The [current contract](../KR-003-REFERENCE-VIDEO-PREPARATION.md) defines full native-frame RGB comparison using overlapping 16×16 tiles, maximum tile MAE 2/255, no whole-frame averaging/masking or held-out learning. This narrow synthetic envelope does not establish Samsung compatibility. The fixture's visible tap counter changes after successful input; correctly functioning later ordinary images may therefore remain UNKNOWN. This is not silently masked or treated as enforcement failure.

Every decoded frame keeps original PTS/time base, integrity, label and context, even on exact-cache hits. Host recorder lifetime is only an outer bound: no verified host/video clock anchor exists, so frames remain UNASSIGNED and phase-specific visual verdicts remain `INVALID_ALIGNMENT_UNVERIFIED`. Native intervals are not physical continuity guarantees. Static freshness, physical interruption sensitivity and capture interference are UNSPECIFIED.

The strongest possible aggregate is `CHARACTERIZED:COMPLETED_NO_CHECKPOINT_AUTHORIZATION`, requiring recognized ordered ordinary → restricted → ordinary labels, independent controls and verified cleanup. Unknown imagery/capture/alignment cannot become phase-specific PASS. Independent established enforcement/input loss remains FAIL; uncertain capture/classification/cleanup is INVALID. No human checkpoint, Home exercisability or Settings/recovery gate is replaced.
