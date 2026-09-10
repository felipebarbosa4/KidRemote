# Test evidence

KR-001 product-fixture, KR-002 repository/CI and KR-003 spike-harness evidence is recorded here.
KR-003 now includes bounded owner-observed physical evidence on one exact Mi 8 configuration; it is not the complete physical matrix or a
production-support claim. No Supabase integration or Play review has been performed, and unrun results remain **UNSPECIFIED**.
The [Samsung SM-X400 evidence](KR-003-SAMSUNG-TRANSPORT-CALIBRATION-2026-09-08.md) records transport PASS and three calibration INVALID attempts
on Android 16/API 36. Never transfer it to Mi 8, Pixel/another OEM, another Samsung model, API, build or power/permission configuration.
[The generic next-device bundles](KR-003-NEXT-DEVICE-BUNDLES-2026-09-08.md) distinguish the executed source-`5a46f75` bundle from the corrected calibration-only handoff.
[The verifier v2 bundle](KR-003-SAMSUNG-CALIBRATION-V2-BUNDLE-2026-09-08.md) was executed once; its [HOST_EXCEPTION evidence](KR-003-SAMSUNG-HOST-EXCEPTION-2026-09-08.md) remains INVALID after permission verification and positive control passed but before any blocked hold.
[The runner-v3 bundle](KR-003-SAMSUNG-CALIBRATION-V3-BUNDLE-2026-09-08.md) was invoked once but its
[host startup failed](KR-003-SAMSUNG-RUNNER-V3-STARTUP-2026-09-08.md) before any device command. Its immutable
[runner-v4 replacement](KR-003-SAMSUNG-CALIBRATION-V4-BUNDLE-2026-09-08.md) was then invoked four times. All four independent
[typed host records](KR-003-SAMSUNG-RUNNER-V4-HOST-EXCEPTIONS-2026-09-08.md) remain INVALID at the same post-ARM/pre-revision-assignment
boundary, with verified cleanup and zero samples. The immutable [runner-v5 replacement](KR-003-SAMSUNG-CALIBRATION-V5-BUNDLE-2026-09-08.md)
corrected only that host alias and ARM reply validation. Its subsequent [Samsung calibration PASS](KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md)
is one excluded configuration-specific active-oracle sample with explicit owner agreement and verified cleanup; it permits qualification-bundle
preparation but supplies zero qualification rows. The resulting immutable [runner-v8 qualification bundle](KR-003-SAMSUNG-QUALIFICATION-V8-BUNDLE-2026-09-08.md)
was invoked once; its [network-preflight INVALID](KR-003-SAMSUNG-QUALIFICATION-NETWORK-INVALID-2026-09-09.md) remains zero-cycle evidence, not an
enforcement failure. Runner-v9's immutable [bundle and hashes](KR-003-SAMSUNG-QUALIFICATION-V9-BUNDLE-2026-09-09.md) remain preserved. Its later
[physical execution](KR-003-SAMSUNG-QUALIFICATION-SCREEN-INVALID-2026-09-09.md) retained 100 automated PASS rows at p95 317 ms but stopped
`INVALID:SCREEN_OR_KEYGUARD` before checkpoint-3 physical agreement. It is one non-resumable INVALID, not a qualification PASS. The immutable
[runner-v10 bundle](KR-003-SAMSUNG-QUALIFICATION-V10-BUNDLE-2026-09-09.md) was then executed once. Its
[Home-phase FAIL](KR-003-SAMSUNG-QUALIFICATION-HOME-FAIL-2026-09-09.md) retained another 100 automated PASS rows at p95 318 ms and final-visible
PASS, but no Home action/result: an out-of-sequence Settings-button action led the automated hold poll to emit `FAIL:RESTRICTION_LOST` while
restriction remained true on an allowed safe surface. The emitted FAIL remains unchanged and the run is not resumable or a Home escape result.
The immutable [runner-v11 bundle](KR-003-SAMSUNG-QUALIFICATION-V11-BUNDLE-2026-09-09.md) was then executed twice. Both independent
[runner-v11 attempts](KR-003-SAMSUNG-QUALIFICATION-V11-ATTEMPTS-2026-09-09.md) retain 100 automated PASS rows but remain INVALID: RUN A stopped
during final-visible polling with failed cleanup/restoration; RUN B retained final-visible PASS but no exercisable Home control/action. Prepared
runner-v12 separates navigation mode from control availability and action outcome. The owner-approved dual path is now available in an
[immutable runner-v12 bundle](KR-003-SAMSUNG-QUALIFICATION-V12-DUAL-HOME-BUNDLE-2026-09-09.md); it has not been physically executed.
OD-40's [immutable excluded dual-Home diagnostic bundle](KR-003-SAMSUNG-DUAL-HOME-DIAGNOSTIC-BUNDLE-2026-09-09.md) reuses that Home logic for one
short exact-configuration check. Its one [physical Path-B diagnostic](KR-003-SAMSUNG-DUAL-HOME-DIAGNOSTIC-PASS-2026-09-10.md) subsequently
passed with verified cleanup. It remains definitionally excluded with zero qualification/TIME-04 rows and no matrix PASS; full runner-v12 remains unexecuted.

Use a dated file with Goal, Context, Constraints, Done when, commit, environment/version/model, test IDs,
synthetic fixture identifiers, steps, observations, samples, failures and conclusions.
Do not include credentials, QR secrets, child identity or content in evidence.
