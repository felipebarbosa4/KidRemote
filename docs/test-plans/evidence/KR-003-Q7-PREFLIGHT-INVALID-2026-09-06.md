# KR-003 Q7 preflight transport failures — 2026-09-06

- **Goal:** Preserve and localize three Q7 pre-sample `INVALID:ADB_REJECTED` results without reclassifying them or exposing raw ADB output.
- **Context:** The owner ran immutable Q7 bundle `4b886e4` three times; every run stopped during attempt 0 before ARM.
- **Constraints:** Read mounted evidence only; no device command, rerun, setting/policy change, raw output, qualification claim or KR-004.
- **Done when:** All runs are independently ingested, the last successful state and rejected fixed operation are established, and the next diagnostic is bounded to oracle transport.

## Preserved runs

| Run | Status | Revision | Positive control | Q7 samples | Human checkpoints | Bailout | Radio restoration |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| `run-20260906-221807-0f52b94f` | `INVALID:ADB_REJECTED` | null | `UNRECORDED` | 0 | 0 | verified, 0/0 samples | Wi-Fi/mobile flags verified 1/0 |
| `run-20260906-221841-388db07a` | `INVALID:ADB_REJECTED` | null | `UNRECORDED` | 0 | 0 | verified, 0/0 samples | Wi-Fi/mobile flags verified 1/0 |
| `run-20260906-221914-a4512378` | `INVALID:ADB_REJECTED` | null | `UNRECORDED` | 0 | 0 | verified, 0/0 samples | Wi-Fi/mobile flags verified 1/0 |

`node tools/kr003/ingest.mjs qualification` independently accepted each as a partial Q7 INVALID with zero automated expiry cycles and zero human
checkpoint sessions. All finalization-error arrays are empty. The original directories remain unchanged under
`C:\platform-tools\kr003-qualification`; no failed attempt was deleted, overwritten, retried into the same directory or promoted to a pass.

Representative integrity anchors:

| Run | `manifest.json` SHA-256 | `attempts.json` SHA-256 | `fixture.jsonl` SHA-256 | `summary.json` SHA-256 |
| --- | --- | --- | --- | --- |
| `0f52b94f` | `c0529519f972a4b81dd5ec7365ebc4023ef4f662628fb1df14cf0725b32865c7` | `33557346381436634944de2a989e143f23f24a681006d9cfaf01995228415671` | `4fd67ca98635d46abcfe902070c8f6e81ce34fc1d5b8c3842c64336c0142849a` | `2226d84b4a9a7202c932cc6559a21972427426303a3adb3d9e3e2cb37046d8ae` |
| `388db07a` | `98d90fdb828ec793ca45fe07a15e1ee8c109076cb381d057548ab9c930759133` | `471c8039bb142ac7d64e512d1b97209fc8dd5bfea1a0275bb4614f286ba951c0` | `5fe9521a01c6c2fd25c6ebbc7ed2541b75640f7aad1c0b611f0b6a7035232dcf` | `5e006ab9717012f6e56372ad428b14d715b8c86046daed68c1ae79241574faa3` |
| `a4512378` | `a2c69295dbaa19ae4ee0213dd7b2ba82d2ecb978dfb42348f23ffbb4003af74d` | `bd3f60a81dacc7881d7b432626e5d0aa5493731e0ba9dd7a5b59481c2dea3852` | `96f304c33471e249a20fa6446070c5afd16e956ea9dcb7b5301be1608478c03d` | `0b6df5410ef5a4100b956848ef092d82d555d4e436b9141a2b05dd4e73d41795` |

## Exact stage and operation

Before the failure, each run successfully completed:

- device and exact APK verification;
- candidate lab-control broadcasts and health checks;
- fixed settings reads;
- Wi-Fi transition to offline plus owner confirmation;
- lab metrics reset;
- candidate CLEAR and ordinary-surface detection;
- fixture launch and two valid fixture-state broadcasts.

The last two fixture snapshots in each run report the same fixture instance, focused/resumed state, `taps=0`, `probeReady=true`, and coordinate
`540,1956`. No after-tap increment exists. Attempt 0 has `Revision=null`, proving ARM was never called. In the immutable Q7 runner, the only fixed
operation after that second pre-control fixture snapshot and before ARM is:

```text
adb shell input tap 540 1956
```

Therefore the exact rejected operation is **established: `INPUT_TAP`**. Candidate/fixture broadcasts and radio/settings commands are rejected as
causes by their later successful evidence. The historical wrapper collapsed non-zero exit, `SecurityException` and `Permission Denial`; exit code
and stderr class remain **UNSPECIFIED** for these three runs.

## Cause boundary and next diagnostic

AOSP documents that the shell identity normally receives input-injection permission. A vendor/configuration denial is plausible, and community
reports point to MIUI's separate `USB debugging (Security settings)` switch, but no official Xiaomi documentation for this exact build or evidence
of the switch's current state is available. The setting requirement is therefore **inferred, not established**.

The next step is the standalone [Q7 oracle-transport preflight](../KR-003-Q7-ORACLE-TRANSPORT-PREFLIGHT.md). It installs/opens only the existing
ordinary fixture, runs one state query and one tap, stores only operation category/exit/stderr class plus numeric counter result, then stops. It
does not arm enforcement or change radios/settings/permissions. Do not rerun Q7 or change the MIUI setting until that result is ingested.
