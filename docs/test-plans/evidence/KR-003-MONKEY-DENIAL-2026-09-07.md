# Mi 8 Monkey denial and qualification blocker

- **Goal:** Ingest the final bounded transport experiment and apply the documented stop condition.
- **Context:** Shell input and separate UiAutomation were denied; owner ran the Monkey probe on September 6 at 23:59 local time.
- **Constraints:** Preserve original files, no device/settings action, no weakened oracle gate or KR-004 work.
- **Done when:** Exact failure, fixture outcome, cleanup and required owner decision are recorded.

Ingested September 7 directly through `/mnt/c` from
`C:\platform-tools\kr003-monkey-transport\transport-20260906-235908-5ce3dfa5`.
All five JSON files were present; `node tools/kr003/ingest.mjs monkey <directory>` validated the result. Originals are unchanged.
UTC interval: `2026-09-07T03:59:08.0464683Z`–`2026-09-07T03:59:18.3578429Z`.

Source: `a10fd34043c0dac20c69a0558104e294a7dba243`.
Helper APK SHA-256: `a272ea3539af9b1872c79c97565e3174a52aae35ea16c448fe50e1b00831f6b7`.
Fixture SHA-256: `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`.

## Established result

Primary result: **INVALID:MONKEY_INJECTION**. Matching transient request `19394211` returned:

```text
Stage=DOWN Outcome=SECURITY_EXCEPTION
DownAccepted=false UpAccepted=false
HelperCleanup=REMOVED_AND_VERIFIED
```

This was not a missing tool class/method, timeout or malformed reply: helper resolution reached DOWN and caught the security exception there.
`MONKEY_TOUCH` returned ADB exit 0 / stderr NONE. UP acceptance is false; a separate UP exception was not retained because the first error takes
precedence. The private MIUI permission-check implementation remains **UNSPECIFIED**.

All 24 ADB operation records have exit 0. `HELPER_PUSH` has stderr class OTHER; its raw text was deliberately not retained and meaning is
**UNSPECIFIED**. It is not evidence of injection denial: the uploaded helper subsequently returned the correlated DOWN result. All other stderr
classes are NONE. `RejectedOperation` is null because the rejection occurred inside the helper, not the ADB wrapper.

Independent fixture evidence: counter **0 → 0**; same process instance `1651449`, coordinate `540,1956`, focused/resumed/probe-ready true,
one focus gain and zero losses before and after. Monotonic elapsed `1651757 → 1655605`, request `2 → 16`.
This corroborates absent input delivery, not an enforcement result.

Both `HELPER_REMOVE` and `HELPER_ABSENCE` succeeded. Only the runner's temporary uploaded helper APK was removed, with absence verified.
Its immutable Windows bundle remains available; original evidence, installed apps and app data were not deleted.
No candidate ARM/CLEAR, permission, radio or developer-setting change was performed. Radio restoration was unnecessary; current radio state
was not measured. Zero Q7 samples and zero human qualification checkpoints occurred.

## Evidence fingerprints

| File | SHA-256 |
| --- | --- |
| fixture-after.json | `7b14cc3a2393fd1c2b31750303abc45bdfd52213e172cae603ebb29b327c1a34` |
| fixture-before.json | `a8319c9f76f1c80fc2beed02025b4b4b33195c6f3a77d1a15a91a29db11be600` |
| operations.json | `6fa34d8bf16f98877111a4518107a91c9a50fc1e1ba947f152a8412049ba7919` |
| probe.json | `443ebd183cecd0d00d0a3e404ef802a20ca50cd37978228bb93f60fc377c65c1` |
| summary.json | `36bc51fb8a8ae7b5e3830d79de0b9544bb9e86063ed6b465d4e539434b322686` |

## Transport decision and boundary

| Tested route | Physical transport evidence | Qualification contribution |
| --- | --- | --- |
| [Shell input](KR-003-MI8-INPUT-DENIAL-2026-09-06.md) | INPUT_TAP exit 1 / SECURITY_EXCEPTION | Zero |
| [Separate UiAutomation](KR-003-UIAUTOMATION-DENIAL-2026-09-06.md) | DOWN SECURITY_EXCEPTION; counter 0→0; framework finish | Zero |
| Bounded Monkey touch class | DOWN SECURITY_EXCEPTION; counter 0→0; helper removal verified | Zero |

The safe tested software-only input paths are unavailable on the reported Xiaomi Mi 8 / MIUI Global 12.0.3 / Android 10 API 29 configuration.
This does not prove every imaginable transport impossible or generalize to other devices. The owner's observed disabled, SIM-gated security
debugging switch strongly supports the configuration explanation; exact internal causality remains **UNSPECIFIED**. No verified supported SIM-free
way to enable that switch is established. Do not guess settings writes or use unrelated developer options.

**Q7 is blocked.** Its positive-control input prerequisite failed, so its three-human-checkpoint model is not physically validated here. The
per-cycle visual fallback conflicts with the owner's maximum-three-human-checkpoint constraint. Do not revert to 100 manual prompts, count
attachment callbacks as passes, rerun Q7, or reject the enforcement candidate merely because lab input transport is unavailable. Existing bounded
enforcement observations remain valid; broader qualification, lifecycle/safety/device and Play gates remain unsatisfied.

Owner decision required; selection is **UNSPECIFIED**:

1. Supply another authorized physical lab device and first test its input transport. Results qualify that configuration, not this Mi 8.
2. Explicitly authorize investigation of a supported Mi 8 lab-configuration change. Preserve before/after and recalibrate transport/oracle;
   success is not assumed. No SIM purchase/insertion or security-setting change is requested by this update.
3. Pause this path or explicitly revise product/support scope through ADR review, without relabelling unproven evidence as passing.

Recommendation: use another already-available authorized physical device if possible, initially only for the tiny transport prerequisite.
Availability is **UNSPECIFIED**; this is not a purchase recommendation. An emulator cannot substitute for required physical/OEM evidence.
Stop at this owner decision. KR-003 remains Open/In Progress administratively, with qualification explicitly blocked; PR #16 stays draft;
KR-004 untouched. No new physical command or bundle is warranted by this run.
