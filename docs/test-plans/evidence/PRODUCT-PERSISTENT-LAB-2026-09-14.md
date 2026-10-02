# OD-51 persistent native laboratory preparation — 2026-09-14

**Readiness is conditional on a successful current-source CI run and an immutable
manifest.** The final source/manifest hash and READY_FOR_ONE_OWNER_RUN publication
are recorded on [PR #24](https://github.com/felipebarbosa4/KidRemote/pull/24). Without
that matching publication/manifest this preparation remains BLOCKED. This document
records attempts independently; it does not revise historical Samsung verdicts.
No physical command, emulator action, WSLInterop repair, sudo, host configuration
change, FCM, deployment or merge occurred.

## Specified and implemented

OD-51 authorizes persistent synthetic lab state and an in-command live host gate,
with no additional standalone owner preflight. Native PowerShell → frozen Windows
Node → native Docker Desktop replaces the Windows→WSL→Windows chain. The separately
owned lease has UUID/source/migration hash labels, exact container IDs, a named
PostgreSQL volume, local-only port bindings and protected DPAPI credentials. The
exclusive Windows file handle covers the complete attempt. Stop retains enrollment;
explicit teardown admits a separate durable event before deleting exact owned
resources. Incompatible, missing or partial ownership/state fails closed.

The real host health probe uses verified Auth/bootstrap, a separate synthetic probe
household, real pairing, canonical expected-version LOCK/UNLOCK, and final SQL
confirmation of no manual lock. It does not mutate the enrolled tablet's policy.
The main physical path remains gated by full host health plus exact read-only target,
APK/signature/fixture checks before the first OD-50 destructive admission. Reuse
verifies saved device/epoch and permissions, then normal sync and canonical operations;
it does not grant permissions, recreate identity or reset uncertain accounting.

Normal run cleanup stops host services and removes its reverse tunnel while retaining
the owned volume, enrollment, APK and permissions. The backend is restartable, not
production hosting. Ordinary input restoration remains an independent required
cleanup result. Manual Accessibility recovery cannot rewrite an original verdict.

## OBSERVED attempts, preserved separately

- Commit `6fecfbd`: local Node lease model 8 tests PASS. CI `34906227424` real
  persistent lease job PASS: creation, real enrollment/authentication, stop/restart,
  exact resource reuse, same identity/epoch/credential and no duplicate child. The
  overall workflow was subsequently cancelled by a new push; it is not an all-CI PASS.
- Commit `e8c1d04`, CI `34906685514`: persistence/control checks passed before a new
  service-log secret scan FAILED. Only the classification was emitted; no secret or
  raw service log entered evidence. Windows tests separately FAILED because a fixture
  closure could not resolve its `Check` helper under PowerShell 5.1. Both attempts
  remain failures. Corrected the fixture scope and disabled retention of service logs
  on the separate lab containers; disposable harness semantics remain unchanged.
- Commit `1f4e134`, CI `34906891950`: new no-log readiness check FAILED because the
  container PID-1 process-name assumption did not establish readiness. Cleanup of
  exact CI resources was verified. Native private-pipe startup also FAILED before
  readiness. No device was involved.
- Commit `ae0309d`, CI `34907130456`: sanitized stage diagnostics isolated native
  startup failure to private readiness parsing (line 52); the first attempt remains
  failed. Database readiness still used the previous process-name assumption.
- Subsequent readiness implementation checks the active PostgreSQL listener setting
  through SQL, without service logs or PID-name assumptions. The upstream entrypoint
  distinguishes its temporary Unix-only initialization server from the final listener;
  actual pinned-image CI validation is required, not inferred from documentation.
  [Upstream entrypoint](https://raw.githubusercontent.com/docker-library/postgres/master/docker-entrypoint.sh).
- Local affected regressions: 31 Node KR-006–009 tests; PowerShell 75 replacement,
  36 transport, 72 prerequisites, 64 independent-oracle, 78 read-only update-review
  checks PASS. Reuse/gate suite first had 49 checks on Linux; removal of the incorrectly
  scoped helper leaves 43 checks, separately rerun PASS. Journal failure coverage
  retains interrupted admission, truncated write, duplicate request and cleanup failure.
- Local Gradle JVM/lint SUCCESS, 13 seconds, 166 tasks (6 executed/160 up-to-date).
  Existing XML/audits: child 84 / parent 14 tests, zero failures. Initial child-audit
  invocation lacked ANDROID_HOME and failed before aapt2; corrected environment-only
  rerun passed. No APK rebuild was substituted for the approved lab artifact.
- Python host observer 3 tests PASS. Private-state shell suite first could not locate
  `pwsh`; rerun with the existing portable runtime on process-local PATH: 4 PASS.
  No system installation or host repair was performed.

## Artifact identity / validation boundaries

Lab APK unchanged: source `668ab87a22591319afd43167d55ef9ac0909c1b3`, v2,
`0.0.2-local-physical-lab`, SHA-256
`f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56`;
signer `638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb`.
Fixture SHA-256 `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`.
Release SHA-256 `ffb42850fe95fe7f6f48f8e00fe89c534743e334462625b4bed4b7d1f2cb60be`;
release/debug audit passes, no new product permissions or enforcement hooks.

Frozen native Node input: Windows PE metadata 24.14.0,
SHA-256 `63c259c81e5d472b5f11c8d506070130cb04a1ecf84b80377a34ed6ec9048088`.
JBR metadata 25.0.3+-15898627-b508.16; java.exe SHA-256
`7148521120f35659dc0b233358a107c67ca7ca92993391519660ee6c80a9df9a`.
These are existing local runtimes, copied only when freezing, never downloaded during
qualification. Every bundled runtime file must be hashed. Owner-installed Node/SDK/JBR
is not required; ordinary Windows PowerShell, Docker Desktop and ADB remain prerequisites.

**NOT_RUN:** exact-PC final native host execution, Samsung replacement/QR/consent,
physical Lock/input/focus/Unlock, emulator campaign. The new owner readiness rule
allows the first exact-PC host validation inside the single runner, before mutation;
these NOT_RUN items alone are not a separate-preflight requirement. Physical p95,
emergency/recovery safety, battery/OEM acceptance and full KR-003 remain unproven.

First-run logical owner actions: scan QR, camera permission if requested, Usage Access,
product consent, Accessibility enable (at most five logical actions). Matching reuse:
zero setup actions. No extra visual confirmation. Duration estimates are not measurements.

## Subsequent native diagnosis and confirmation

- CI `34907287994` (source `0fd01ce`) real lease **12 checks PASS**, exact task teardown
  verified. Native startup still failed with a syntax-class failure in the child
  private pipe. No raw exception body/configuration was emitted.
- CI `34907556636` (source `190e309`) preserved a second syntax-class failure after
  byte-oriented writes alone did not remove the marker already emitted at pipe
  creation. It is not counted as a passed framing test.
- CI `34907715108` (source `1e43d65`) isolated **JSON_FRAME_65279**, one leading
  UTF-8 BOM. The .NET Framework Process implementation constructs the stdin writer
  using Console.InputEncoding and enables AutoFlush. No console/host configuration
  was changed: the private parser now accepts exactly one optional BOM and still
  rejects duplicate markers, malformed JSON and oversized input. Host QR rendering
  strips the same framing marker before encoding the actual QR payload.
  [Microsoft reference source](https://raw.githubusercontent.com/microsoft/referencesource/main/System/services/monitoring/system/diagnosticts/Process.cs).
- CI `34907885944` (source `2695f33`) advanced past native startup, then FAILED at
  protected-file replacement: PowerShell 5.1 bound a null backup filename as an
  illegal empty path. The atomic replace now passes an explicit NullString; no
  delete-then-write or weakened durability fallback was introduced. The failed
  attempt and its partial-write behavior remain independent.
- CI `34908064750` (source `898dd49`) Windows job **PASS**: 12 native PS5.1 DPAPI,
  private-pipe/fake-Docker, concurrent-run rejection, saved-identity and second-start
  checks; PS7 repeats 5 DPAPI/lock checks. Host gate/reuse **43 checks PASS** on each.
  Existing native fake ADB **6 checks PASS**. Real lease job **12 checks PASS** with
  PostgreSQL/Auth/gateway, identity/epoch/credential reuse and exact cleanup. The
  whole run was later superseded by final validation changes; completed job results
  are not promoted into an overall workflow PASS.
- Current lease model has **9 tests** (including strict private BOM framing).
  Host QR has **5 checks**: normal/BOM equivalence, PNG/dimensions and empty/oversized
  bounds. Owner script files are frozen with UTF-8 BOM for Windows PowerShell 5.1;
  imports of all **13** owner modules and entrypoint syntax are tested without devices.
  A final privacy guard additionally requires PostgreSQL's file logging collector
  to be off; container log retention is disabled and validated on every reuse.

All superseded workflows are retained as CANCELLED/partial, never pooled into one
passing run. The authoritative complete CI run must match the frozen source commit.
The final owner bundle contains the existing Windows Node/JBR distributions, local
SDK apksigner, host QR helper, all relevant source and both reference APKs. Every
file is hashed; the Node license is included. No executable download, Node install,
SDK install or WSL entry occurs during the owner run. Pinned Docker image acquisition,
if needed, is confined to the native host preflight before any tablet mutation.

## Owner-run interpretation and cleanup

READY_FOR_ONE_OWNER_RUN means a safe attempt with all device mutations gated behind
live host readiness. It does not mean the exact PC or Samsung path has already passed.
Expected first setup is approximately 5–12 minutes with cached images; image pulls
may extend host-only preparation. Matching reuse is estimated at 1–3 minutes with
zero repeated setup actions. These are **INFERRED estimates**, not measured latency.

PASS requires positive fixture input, canonical Lock, blocked independent input/focus,
consistent product corroboration, canonical Unlock and independently restored input.
Usable fixture input/focus under restriction is FAIL. Ambiguity or failed prerequisites
is INVALID; host-gate failure is INVALID_HOST_PREFLIGHT and admits no device mutation.
Original verdict is immutable. Failed canonical restoration offers the separate manual
product-Accessibility recovery path, without converting the verdict to PASS.

CI lease containers/volume/network are removed only after exact ownership verification.
No new local Docker/emulator resource was started in this preparation. The previously
reported OD-50 supervisor residual-resource inventory on the owner PC remains
**UNSPECIFIED**; it was not repaired or silently cleaned. The new live gate rejects
conflicting ports/resources before device mutation rather than adopting them.
Future successful runs deliberately retain synthetic database data/enrollment and the
lab APK/permissions, while stopping services and removing the attempt's own reverse.
A partial backend start is reported as persistent-state review required, not as proof
that no backend resource was created. The owner should paste only the final sanitized
JSON, never protected lease files, tokens, QR data, copied APK bytes or raw ADB output.
