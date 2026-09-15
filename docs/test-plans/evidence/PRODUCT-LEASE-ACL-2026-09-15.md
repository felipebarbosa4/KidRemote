# OD-51 lease directory ACL diagnosis

[Task contract](../../exec-plans/PRODUCT-LEASE-ACL.md). No physical command, Windows
executable, interop repair, secret decryption or host-state mutation during diagnosis.

## Preserved observation

Diagnostic `c5c56ac0-6530-4f01-9472-349239fb225a`, source
`60fd897f0446ecb4c8c579e7a9884142060ef5b2`, at 2026-09-15 15:49:10 UTC:
LEASE_STATE / HOST_PREREQUISITE, INVALID_HOST_PREFLIGHT, result cleanup UNVERIFIED.
Attempt `18240f7d-ee1d-4b72-90e3-5b1cf8cda798` contains only VERDICT INVALID
and CLEANUP NOT_REQUIRED. These two existing representations remain unchanged;
the journal field does not retrospectively upgrade the result's cleanup.

OBSERVED metadata: physical-lab already exists. runner.lock exists (0 bytes),
lease.dpapi exists (2284 bytes), resources.json exists (651 bytes); all modification
times are 01:25 UTC, preceding this failure. No lease.dpapi.tmp exists. Public resource
record is complete, format 1, exact synthetic lease dba3a169-19ad-4744-aff1-6e6cf572a58b,
source 3693034816039de67087066f077e6e02a9507dd6 and schema
7d9c6f3c1c85fd3f91070f7bad0ce90b4e114ca3f4cbbaaeb02eb799eec7a00a.
No protected contents were read. Existing persistent state must not be reset.

**Exact Windows root cause: UNSPECIFIED.** No native exception or NTFS ACL was retained.
Linux mount permission bits cannot establish Windows ACLs. The wrapper's generic code
is consistent with the untyped Protect-LabDirectory seam before the inner try/catch.
It does not prove whether creation, ACL construction or Set-Acl failed. File timestamps
cannot prove lock acquisition or DPAPI read, which need not write files. Docker engine
failure would carry a different typed stage; it is not established as the cause here.

## Bounded correction

Protect-LabDirectory now executes inside typed handling. Exact path, non-reparse
containers and current-user ownership precede repair. New directories explicitly set
current-user ownership. Exactly protected current-user + SYSTEM FullControl rules are
read and reused without Set-Acl. Only inherited initialization grants or existing own
rules can be repaired; explicit foreign/deny rules, unknown files or owners fail closed.
Repair records ADMITTED/APPLIED separately with create-new/fsync metadata; never deletes
lease data or alters old attempt results. Partial protected state and orphan resources
are typed conflicts, not silently recreated. Full existing Docker ownership/schema/
compatibility checks still apply after directory admission.

Native PS5.1/PS7 ACL/DPAPI validation and full CI are required before freezing a new
bundle. Synthetic denied-operation injection must not be described as actual OS denial.
Old source-60fd897 command is retired. No additional owner diagnostic is requested.
Readiness remains BLOCKED until native tests, full CI and immutable freeze complete;
final source/hash/CI verdict are recorded in the PR handoff.
