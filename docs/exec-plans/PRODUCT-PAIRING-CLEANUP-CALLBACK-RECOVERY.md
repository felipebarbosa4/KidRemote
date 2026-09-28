# OD-51 pairing-cleanup callback recovery

- **Goal:** Diagnose and correct the preparation callback failure in immutable
  product attempt `a2f91a25-0acc-4fff-848d-10fa99e5af53`, admit only its
  evidence-proven pairing-session transition, and continue the bounded physical
  product slice autonomously.
- **Context:** Source `b541595a33eee5ae3a4eecd6385780ae906426b7` passed
  host validation and cancelled the exact abandoned pairing session, then
  admitted `REVERSE_ADMITTED` but failed before creating the reverse. The
  sanitized result retained the previous preparation stage and a generic
  orchestration code. PR #24 remains draft.
- **Constraints:** Preserve all physical attempts and diagnostics byte-for-byte;
  never promote an INVALID result or UNVERIFIED cleanup; query only the
  task-owned synthetic backend and KidRemote lab package; never persist or print
  JWTs, QR secrets, pairing tokens, serials, raw sensitive stderr, or unrelated
  private data; no destructive device operation, security bypass, merge,
  deployment, publication, or issue closure. Physical progress may use the
  explicitly authorized Windows ADB workflow and pauses only for a human QR scan
  or Android consent.
- **Done when:** The exact callback failure is reproduced without ADB, the
  dynamic-module boundary records the next stage on Windows PowerShell 5.1 and
  PowerShell 7, the immutable attempt and backend transition are narrowly
  reviewed, all relevant PowerShell/backend/SQL/JVM/Gradle/security/privacy and
  required CI gates pass, historical hashes remain unchanged, a replacement
  immutable bundle is frozen, and the physical slice reaches a verified result
  or a genuine human-interaction blocker.

## Resumption - 2026-09-28

**OBSERVED:** the clean integration checkout resumed at `db890983e801913f1c3bce66b32277ce2b411d2f`.
The callback correction and its exact-source CI were already complete, but the immutable
freezer still described only the older `d9157ae6` and `28756da0` attempts, still
called the latter verdict latest, and still described its now-resolved pairing session
as open. The reviewed-attempt catalog already contains the later `a2f91a25` INVALID
and its exact `OPEN -> CANCELLED` pairing transition.

**Action:** align only freezer metadata/current runner guidance with the reviewed history,
add a regression that rejects the stale open-session description, run the relevant
device-free tests, then publish/freeze a replacement only after exact-source CI passes.

**Evidence boundary:** this correction is host/repository preparation only. It does not
reclassify any physical attempt, prove Samsung enforcement, authorize another device,
or replace the required independent physical oracle and human consent/observation.
