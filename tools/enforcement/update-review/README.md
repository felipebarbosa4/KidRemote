# OD-49 read-only signer and private-state review

One owner handoff only. No installation/update, permission change, app launch/input, backend, reverse, clear-data or uninstall. Agent performs no physical command. PRODUCT_PHYSICAL_ORACLE remains BLOCKED.

## Concrete signer finding

Owner reports installed SHA-256 `3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9`, version 1 / `0.0.1-local`. The preserved local source-14d82db APK has exactly that hash. SDK apksigner verifies its certificate SHA-256 as `771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7`.

Approved lab APK source `668ab87a22591319afd43167d55ef9ac0909c1b3`, hash `f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56`, version 2 / `0.0.2-local-physical-lab`, signer `638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb`. Both use `dev.kidremote.child.unassigned.debug`. Lab registers `dev.kidremote.child.enforcement.ChildEnforcementService`, uses fixed debug-only `http://127.0.0.1:47366`, and retains release isolation. Exact approved bytes are reused, never rebuilt or re-signed for this bundle.

**SIGNER_MISMATCH_BLOCKED is inferred for the installed package from the owner-reported exact APK hash plus independently verified archived bytes.** It is not a fresh agent device read. The new handoff pulls current installed bytes and verifies them again. The current lab APK is not eligible for the ordinary signer-compatible replacement path. No key, keystore, signing bypass or alternate update design is introduced.

[Android signing](https://developer.android.com/studio/publish/app-signing) and [SDK apksigner](https://developer.android.com/tools/apksigner), checked 2026-09-14, describe update signing continuity and certificate verification. No update is executed to test rejection.

## Fixed read-only flow

The manifest pins all four bundle files (including the approved lab reference APK), source, Java executable and installed SDK apksigner JAR hashes. Local Android Studio JBR runs the installed SDK JAR directly; no Java PATH/SDK/host configuration repair is needed. `--enable-native-access=ALL-UNNAMED` is a process-only option for this verified SDK dependency, not an Android permission. All tool output stays in memory and is reduced to verified certificate digests.

Before device reads, verify the lab bytes and signature. Reuse the prior strict inventory/configuration/serial-redaction adapter. Require the exact installed version/hash reported by the owner. Pull only the parsed base APK path into a new task-owned host temporary directory, rehash it and call `apksigner verify --verbose --print-certs`. Reject mismatched hash, verification error, multiple/ambiguous signers or unavailable tools. Delete copied installed APK bytes in `finally`; only hash/certificate records survive normal success/error paths. The original archived APK and approved lab reference are existing evidence and remain preserved.

Read-only `run-as ... sh` receives a fixed stdin program, never arbitrary owner input. It uses existence tests/stat on the known identity, pairing, accounting, write-intent, sync and consent paths and their atomic/SQLite sidecars. It counts other durable files without printing their names; symlink/unreadable/ambiguous states fail closed. No file contents, credential bytes, encrypted payloads or DB rows are read. Two metadata snapshots must agree. APK path/hash is rechecked afterward. No product code, service, instrumentation, receiver or Activity is launched.

An identity blob is only potential enrolled identity. Removal and rotation are inside encrypted identity; ACK/report details are inside Room. They are **not decrypted/read**. Their presence cannot be certified by filename alone. Any durable file, pending/sidecar marker, unknown extra file or incomplete inventory yields PRIVATE_STATE_REVIEW_REQUIRED unless signer mismatch already supplies the stronger blocker. Prior historical absence evidence is not reused as current state.

## Exact classifications

- SAFE_DATA_PRESERVING_UPDATE_REVIEW: pinned same package/version progression, verified same signer, consistent complete empty durable-state inventory. Technical eligibility only, not update authorization or an application migration guarantee.
- SIGNER_MISMATCH_BLOCKED: verified certificate differs from approved lab.
- PRIVATE_STATE_REVIEW_REQUIRED: durable state exists or cannot be safely inventoried.
- LAB_APK_PROVENANCE_UNVERIFIED: lab/tool reference integrity or signature cannot be established.
- READ_ONLY_REVIEW_INVALID: target/hash/read/transport/schema/cleanup failure.

Unique sanitized JSON results remain under `%LOCALAPPDATA%\KidRemote\update-review-results`. Temporary installed bytes use `update-review-temp/<attempt>/installed-base.apk` and are removed before normal output. Hard host termination/power loss can interrupt `finally`; any resulting orphan is local-only and requires explicit host cleanup/review, never deletion of device state. No success is claimed for an interrupted run.

Paste only emitted JSON, never serial/raw ADB/tool output. Expected duration is approximately 1–3 minutes, unmeasured on Samsung; reads, pull and verifier have bounded timeouts. No future install or qualification command is provided.
