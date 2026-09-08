# KR-003 Q3 focused recovery diagnostic handoff — 2026-09-06

Historical handoff: the owner executed this bundle and the [preserved result](KR-003-Q3-RECOVERY-2026-09-06.md) records Digital Wellbeing and
recovery-button physical FAIL. The immutable bundle remains unchanged; the physical status below is its initial handoff state.

- **Goal:** Provide one immutable, diagnostic-only Windows command for the labelled Mi 8 Digital Wellbeing/recovery case.
- **Context:** Q2 physical Settings/recovery FAIL; Q3 source `53327c50afb97c66620dd15780114b6f1a13ec33` passed exact-source CI.
- **Constraints:** Owner-operated Windows ADB; no Q2 rerun, 100 samples, policy/allowlist change, identity capture, network mutation or KR-004.
- **Done when:** Bundle/source/APK identities are verified and the owner has one command plus an independently callable lab-only bailout.

Physical execution at initial handoff: **Not run**. It was subsequently executed with the outcome linked above.

## Immutable bundle

Windows directory: `C:\platform-tools\kr003-qualification-bundles\53327c5`

| Artefact | SHA-256 |
| --- | --- |
| `bundle.json` | `d1aa12e4f6bde6e12225902c74fcde772bde972d69d170aeaffe526f109b567a` |
| `Start-KR003.ps1` | `23a72ce3594fa6033e8eb4dbac50bb9b2f15a0b5f4c457f58990be0b6233c95c` |
| `Clear-KR003-Lab.ps1` | `9b940d171145ccd76a4f1695310aacee3e1c7604b3040e8460d318d5a859a8b3` |
| `Qualification.psm1` | `bb87b8386362acd60cd88672789a302c99e72c509c750e7e72a6139fb5e66799` |
| `protocol.md` | `6da5c1f12d95a895d3d74376d0173cbad712f7cd85c0c0279c08c45acc218529` |
| `candidate.apk` | `1c97a382d686c209676f76893e4a7b404853d6481bd30d3cb33e423943617630` |
| `ordinary-fixture.apk` | `6653f10b527cc9a273a8c0ea045cd250f6978c1acfb8e92b00b701f6c14f84bb` |

All seven directory entries were re-read after packaging; every manifest hash matched and all six payload files were byte-equal to source/build
outputs. Q2 directories were not modified. Candidate/fixture APK hashes remain unchanged because no Android source or enforcement policy changed.

## Exact diagnostic command

Run once in owner-operated Windows PowerShell with only the authorized Mi 8 connected:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\53327c5\Start-KR003.ps1" -RecoveryDiagnostic
```

The Q3 bundle rejects omitted diagnostic mode, `-CalibrationOnly`, and `-OfflineNetwork`. It cannot enter the 100-sample loop.

Physical sequence:

1. Watch the fresh expiry remain continuous for the full ten-second hold; answer P/F/I only at its prompt.
2. `SETTINGS_ROOT`: tap the overlay's **Open device settings** once; briefly verify top-level Settings responds; answer P/F/I.
3. `DIGITAL_WELLBEING_ATTEMPT`: tap **Digital Wellbeing & parental controls** exactly once and no other destination; answer P if usable, F if blocked, I if uncertain.
4. `RECOVERY_BUTTON_ATTEMPT`: if the overlay exists, tap **Open device settings** exactly once; answer P if usable top-level Settings returns, F if it remains blocked/unusable, I if uncertain.
5. Wait while the runner records post-state, automatically clears the lab restriction, verifies latency samples are unchanged and writes evidence.

Expected duration: **4–7 minutes** (estimate, not measured). A physical F is retained and the runner continues where scientifically possible;
it never substitutes another attempt. Exit 0 means diagnostic capture and bailout completed, not physical/product PASS. Do not explore other Settings
paths, press Home, change network/permissions or rerun a step.

## Emergency lab-only bailout

If the runner terminal is forcibly interrupted or the device remains trapped, open a second owner-operated PowerShell window and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\53327c5\Clear-KR003-Lab.ps1"
```

The bailout integrity-checks its script/parser, then invokes only debug SNAPSHOT/CLEAR and verifies unarmed/unrestricted/detached state plus the
unchanged latency sample array. It does not clear app data, uninstall, alter permissions/network or count as consumer recovery evidence.

## Verification

[CI run 34056094159](https://github.com/felipebarbosa4/KidRemote/actions/runs/34056094159) passed all three jobs on exact source `53327c5`:

- Android: 23/23 JVM cases, debug/release lint/assembly and merged-manifest/release-DEX isolation audit;
- Linux PowerShell 7.6.5: 54 oracle/orchestration and 80 finalization/bailout assertions, all device calls stubbed;
- native Windows PowerShell 5.1: the same 80 finalization/bailout assertions, all device calls stubbed;
- eight Node evidence/security tests, repository validation and whitespace check.

Local packaging reran Android verification, repository validation and release audits. WSL did not execute PowerShell or ADB. No physical result is
inferred from CI, hashes or synthetic tests. Ingest the eventual owner run with `node tools/kr003/ingest.mjs diagnostic <mounted-run-directory>`.
