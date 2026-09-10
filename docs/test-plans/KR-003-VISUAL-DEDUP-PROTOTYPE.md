# KR-003 synthetic content-deduplication prototype — 2026-09-10

## Scope

This is a repository-local prototype in the existing `VisualCalibration.psm1`, not a physical runner change. `Invoke-KRVisualDedupPrototype` requires `SyntheticOnly`; no entrypoint calls it. The prior [validity review](KR-003-VISUAL-VALIDITY-REVIEW.md) and all its counterexamples remain valid for the unchanged v1 classifier. No Samsung operation, private-media access, qualification, bundle publication, historical reinterpretation or KR-004 work occurred.

The prototype returns zero qualification/TIME-04 rows, `MatrixContribution=NONE`, `HumanObservationSerialized=false` and `CheckpointSubstitutionAllowed=false` for every analyzed sequence. Its PASS means synthetic baseline/optimization equivalence under the test contract, not calibrated physical visibility.

## Mechanism

- Every frame retains index, original start/end ticks, phase, computed SHA-256, image label and a freshly evaluated phase verdict. Integrity, dimensions, capture result, index order, timestamp order and phase-window membership are checked even on duplicates. Bad integrity cannot enter/reuse the cache.
- PNG lookup uses SHA-256 of actual encoded bytes, then exact byte-by-byte equality before reusing the decoded image's label. Size is only an early inequality check, never equality proof. Novel PNG bytes are decoded once to full-resolution RGBA8, without resizing or similarity thresholds. Alternative encodings are conservatively decoded/recognized again; decoded-image uniqueness counts still use exact pixels.
- `DECODED_RGBA8` accepts already-decoded full pixels, not compressed video packets, packet lengths or packet hashes. The same hash-plus-exact-equality lookup operates on pixels at this boundary. There is no video capture/codec or second video decode pass in this prototype; real video end-to-end performance remains **UNSPECIFIED**.
- Cache entries hold content plus image labels only, not phase verdicts. A cached ORDINARY label occurring in RESTRICTED produces FAIL. Unrecognized pixels are UNKNOWN/INVALID, including a one-channel change in one pixel; no unvalidated tolerance erases small changes.
- Independently authored synthetic ordinary/restricted references are cloned and frozen before evaluation. Classification is exact full-pixel matching against these references; it never learns from evaluated frames or candidate state. Their provenance is established by the synthetic test construction, not by trusting a physical telemetry label. This conservative classifier is a correctness baseline, not a usable calibrated physical classifier for dynamic surfaces.
- Cache scope is one invocation. Context binds fixed classifier version `EXACT_RGBA_V1`, reference version and content hashes, format, RGBA8 interpretation and dimensions. Both reference changes and version changes invalidate prior identities. Returned output includes only the context digest, never references, pixels or encoded media.
- All timestamps reach the existing temporal-metrics function regardless of recognition reuse. Its 1,500 ms / 90% filters remain explicitly **synthetic benchmark filters**, not an accepted physical sensitivity contract. Missing samples/gaps, reused timestamps or unverified liveness do not become valid because cache hits exist. Capture liveness is separately supplied as synthetic test evidence and defaults to UNKNOWN; no image-uniqueness count establishes freshness. Within-phase static/frozen ambiguity remains unresolved.

For an independently recognized phase contradiction, FAIL remains retained even if another check is INVALID; per-frame INVALIDs and coverage/liveness status are also retained. Unknown imagery is not evidence of an escape by itself.

## Tests and measured runtime

Native Windows PowerShell 5.1 passed **201 dedup assertions**, including:

1. Different synthetic PNGs with equal dimensions and equal encoded byte length both recognized; equal-size decoded images also distinguished.
2. Exact duplicates reuse recognition; a forced hash-bucket collision still requires exact equality.
3. One changed captured pixel is evaluated and becomes UNKNOWN, not silently skipped.
4. Cached ordinary imagery during restriction retains FAIL.
5. A stable third surface stays UNKNOWN; no self-fitting occurs.
6. Cached/uncached labels, verdicts, reasons, timestamps, hashes, unique-image counts and temporal results match across valid, escape, unknown, changed-reference, integrity and timing cases.
7. Missing/truncated coverage, stale/unknown liveness, invalid timestamps and phase context remain invalid despite duplicates.

The existing **58 visual-validity assertions** still pass, including the v1 failures reproduced by the preceding review. Native PowerShell reserved-variable audit passes. All **28 Node evidence/security tests** pass, including five focused visual tests covering no prototype physical-entrypoint integration and no image-bearing result fields. Repository validation and whitespace checks pass. The new synthetic suite is registered in the existing Linux/PowerShell and Windows PowerShell 5.1/7 CI commands; PS7 is unavailable locally and no new remote CI run is claimed. No unrelated Android builds are repeated.

Benchmark: 60 in-memory synthetic **64×64 PNGs**, two warm-up analyses per workload, then three measured runs in alternating cached/uncached order. The outer stopwatch covers the complete analyzer invocation, including frozen-reference snapshot/hash, per-frame integrity hashing, cache lookup/exact comparison, actual PNG decoding, unique-pixel inventory, recognition, timing/phase checks and result construction. It excludes synthetic PNG generation, capture/file I/O (none performed), process startup/warm-up and printing the report. The uncached baseline has no label-cache lookup/reuse and decodes/classifies every frame; both modes count decoded unique images with exact equality.

| Workload / mode | Frames | Unique decoded images | Decodes | Recognition calls | Cache hits | Three total times (ms) | Median (ms) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Repeated / uncached | 60 | 2 | 60 | 60 | 0 | 443.145, 426.558, 416.699 | 426.558 |
| Repeated / cached | 60 | 2 | 2 | 2 | 58 | 29.907, 30.437, 23.734 | 29.907 |
| All novel / uncached | 60 | 60 | 60 | 60 | 0 | 229.358, 239.982, 230.046 | 230.046 |
| All novel / cached | 60 | 60 | 60 | 60 | 0 | 246.669, 244.380, 242.107 | 244.380 |

**OBSERVED:** median repeated-workload analysis was about **14.3× faster**; all-novel analysis was about **6.2% slower** with caching. The all-novel workload intentionally returns UNKNOWN/INVALID and exact comparisons can exit early; its times are not comparable to known-image recognition complexity. These are small synthetic analyzer measurements, not Samsung capture throughput, qualification runtime or a general speedup claim. Cache storage grows with unique content; eviction/resource tuning is not implemented for this bounded test.

## Smallest next step

Keep this optimization disconnected from physical runners. First specify how owner-local independently verified reference acquisitions are frozen and negatively validated, and separately resolve the required capture sensitivity/liveness contract. Only then consider integrating this exact-equality cache into that validated analyzer. Deduplication cannot repair an interruption missed between captures, establish physical Home exercisability or justify replacing any human checkpoint.

All generated PNGs and pixels exist only in synthetic test memory and are disposed/released without writing media files. No upload path, image display, production permission or release code was added. Immutable `0596173` remains exploratory and unchanged.
