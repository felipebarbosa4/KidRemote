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

## Recovered checkpoint after PC restart

HEAD was `a82db394d258a4065cd72f2177d08bafc8b017e1`, on the original branch,
with only seven uncommitted ACL rejection-test lines. Those lines were preserved.
No local test process survived. CI [34991796915](https://github.com/felipebarbosa4/KidRemote/actions/runs/34991796915)
finished successfully for that exact HEAD: six jobs, native ACL 40 checks on PS5.1
and PS7; lease/DPAPI/transport 20 on PS5.1 and 5 on PS7. No new immutable bundle
had been frozen. The interrupted activity beyond this checkpoint is UNSPECIFIED.

Host-only native readback now confirms current-user ownership, protected inheritance,
and exactly two noninherited FullControl rules (current user and SYSTEM, child/file
inheritance, no propagation flags). Lease file sizes/timestamps match the preserved
observation above. Historical diagnostic/result/journal and protected secrets were
not modified or decrypted. This is current-state evidence, not the failure-time ACL.

Independent resumed validation attempts:

- One wrong UNC distribution path failed before script execution; two correct UNC
  invocations were refused by the existing signing policy. No policy change followed.
- Native PS5.1 ACL test from local NTFS failed at test setup's `Set-Acl` with actual
  `PrivilegeNotHeldException` / `SeSecurityPrivilege`. Loading explicit descriptor
  sections alone did not fix that same unprotect operation (second failed attempt).
- Direct .NET persistence of modified sections passed the isolated protected/inherited
  ACL control. Implementation now loads Access/Owner/Group explicitly and persists
  modified sections through Directory.SetAccessControl (PS5.1) or
  FileSystemAclExtensions.SetAccessControl (PS7), without an audit-SACL write or
  elevation. Existing user/SYSTEM admission and idempotence remain enforced.
- Corrected native PS5.1 ACL suite: **49 checks PASS**, actual NTFS and synthetic
  DPAPI round trip. Denied-operation injections remain labeled INJECTED; foreign-owner
  fixture is injected, foreign explicit allow is an actual NTFS rule and remains
  unchanged after refusal.
- First copied lease-suite invocation lacked its relative lease.mjs fixture and
  failed before native-pipe startup; its synthetic temporary state was cleaned by
  finally. This is a harness-copy failure, not a lease or physical result.
- Local Node lease/compatibility: **18/18 PASS**, zero skipped/failed. Repository
  validator and `git diff --check`: PASS.

The current host reproduces a Set-Acl privilege failure, but the exact API/exception
in the historical physical attempt remains **UNSPECIFIED**. No historical verdict is
promoted or replaced. Full current-source Windows CI and immutable freeze still gate
publication of the replacement command.

API semantics checked 2026-09-15: [DirectorySecurity sections](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.directorysecurity.-ctor),
[AccessControlSections](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.accesscontrolsections),
[Directory.SetAccessControl](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory.setaccesscontrol?view=netframework-4.8.1)
and [FileSystemAclExtensions.SetAccessControl](https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemaclextensions.setaccesscontrol).

Correct relative-layout native PS5.1 lease rerun: **20 checks PASS**, including
private native Node/fake-Docker pipe, independent restart, DPAPI, exclusive lock and
typed stage propagation. Real Docker and ADB were not invoked by that suite.

### Historical-function control and CI refusal fixture scope

The exact source-60fd897 Protect-LabDirectory function was also executed twice in
one newly generated synthetic temporary directory, using native local PS5.1:
first call PASS; second call FAIL with PrivilegeNotHeldException / SeSecurityPrivilege.
No physical-lab path was used. This reproduces the old idempotence defect on the
current host; it cannot supply the missing failure-time exception retroactively.

The first resumed CI [35026229971](https://github.com/felipebarbosa4/KidRemote/actions/runs/35026229971)
failed at ACL assertion 19: the new foreign-owner injected closure was constructed
inside Expected's function scope. Standalone `-File` passed, whereas nested script
invocation lost the fixture variable. The callback is now bound at its defining
script scope. Nested native PS5.1 invocation passes all **49** assertions too.
This was a test-fixture scope defect; no owner ACL or lease was altered by it.
The CI failure remains independent, and a new complete CI run is required.

Local isolated Gradle suite: **BUILD SUCCESSFUL**, 274 tasks (6 executed,
268 up-to-date), followed by audit-build: **24/24 JVM tests**, both merged manifests
and release isolation PASS. QR private-pipe checks: **5 PASS**. Missing `/tmp`
freezer inputs were recovered from hash-verified immutable source-60fd897 artifacts;
HostQr.java is byte-identical, so the completed helper was reused without rebuilding.
