# KR-003 debug qualification preparation — 2026-09-06

- **Goal:** Produce a verified owner-operated qualification bundle without manufacturing physical evidence.
- **Context:** Branch `kr-003-mi8-overlay-stability`; `de941a9` fixed the established own-package loop; `8786dc5` ingested ten complete checkpoint cycles.
- **Constraints:** KR-003 only; no WSL/host modification, sudo, device execution, policy approval, deployment or destructive action.
- **Done when:** Desktop tests/release isolation pass, exact bundle identities are recorded, and owner execution is the remaining step.

## What changed

Debug-only ordered-result receivers export exact revision/sample counts, bounded aggregate latency numbers, coarse state and sequence-numbered
trace records. Both receivers require sender DUMP permission; neither app requests DUMP. A separate ordinary fixture supplies its own focus/resume
and synthetic touch counter. It has no permissions and no Accessibility capability. Candidate debug control only calls existing lab clear/arm and
metric-reset operations. The main service adds read-only observation hooks and revision-labelled trace calls; release hooks are no-ops.
The original surface resolver/enforcement rules, safe allowlist and timer reducer are unchanged.

The PowerShell runner verifies bundle and installed APK hashes, exports prior counters, calibrates the new build/fixture, then records exactly
100 fresh paired observations if calibration succeeds. Clear/arm/navigation, metrics, state capture, statistics and failure journalling are automatic.
Physical observation remains required; fixture focus/attachment cannot award PASS. The explicit offline option journals/restores radio flags.
No raw logcat/dumpsys output, content, node text, screenshots, accounts, serials or personal package history is collected.

## Executed desktop checks

| Check | Actual result |
| --- | --- |
| `testDebugUnitTest` | 22/22 candidate JVM tests; fixture has no JVM cases, not a claimed runtime test |
| `lintDebug`, `assembleDebug` | Passed for candidate and fixture |
| `lintRelease`, `assembleRelease` | Passed for candidate and fixture; unsigned release APKs, not production builds |
| Merged manifests and DEX | Both variants audited; exact existing candidate permissions, zero fixture permissions; debug controls/trace absent in release |
| `Qualification.Tests.ps1` | 43 assertions passed using synthetic snapshots/operator replies and harmless local process stubs; never ADB |
| Node test suites | 3 passed: checkpoint integrity, qualification evidence integrity, negative least-privilege mutation checks |
| `node tools/validate.mjs` | Passed |
| `git diff --check` | Passed |

The PowerShell test's synthetic 100-cycle sequence is **not physical evidence**. Tests reject missing/ambiguous/unsanitized replies, duplicate
revisions, telemetry-only 'passes', short/missing observations, mutated sample history, restriction removals, service/eligibility loss, fixture
focus and p95 threshold failures. Radio-command selection is tested in memory, not on MIUI.

AGP exposes debug unit-test tasks in this project; `testReleaseUnitTest` was not an available task and was not claimed executed. Release safety is
covered by source-set/manifest/DEX and release lint/build checks. Linux PowerShell 7.6.5 is a portable user-cache tool; its archive hash matched the
official release SHA-256 `b34ab3b19acac1d3d4d0d3cfdb02acf62f457b0b6a962ff008132033f7566844`.
Sources: [Microsoft portable installation](https://learn.microsoft.com/powershell/scripting/install/install-other-linux),
[official 7.6.5 release](https://github.com/PowerShell/PowerShell/releases/tag/v7.6.5). No sudo or host configuration change was used.

## Unexecuted and limitations

- New Windows runner, DUMP receiver on MIUI, ordinary-fixture physical behaviour and radio command compatibility: **Not run**; preflight/calibration required.
- 100-sample qualification: **Not run**. The existing Mi 8 record remains eleven post-fix independent observer-confirmed expiries, including the ten-cycle checkpoint.
- The checkpoint log contains headers only; its empty trace cannot corroborate state transitions. Its internal latency denominator is **UNSPECIFIED**.
- Runtime ordinary-app sender-denial and traffic checks: **Not run**. Static checks do not replace them.
- API 28/35/36 physical configurations, remaining lifecycle/permissions/tamper/emergency/TalkBack and policy/go-no-go: outstanding.
- Google Play review/acceptance, Supabase/RLS integration tests and production backend: no evidence; no such work performed here.

This evidence permits owner-run calibration/qualification, not KR-003 closure or KR-004 implementation.

## Published verification

Automation source `34e566e` and focus-callback hardening `d81f19a` were committed/pushed. Both jobs passed for `d81f19a` in
[GitHub Actions run 34017273906](https://github.com/felipebarbosa4/KidRemote/actions/runs/34017273906).
The [exact packaged operator handoff](KR-003-BUNDLE-2026-09-06.md) records the verified mounted files and next command.
