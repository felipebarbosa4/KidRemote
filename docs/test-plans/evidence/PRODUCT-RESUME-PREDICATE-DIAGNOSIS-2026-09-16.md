# OD-51 source-07cf5e1 resume predicate diagnosis

[Task contract](../../exec-plans/PRODUCT-RESUME-PREDICATES.md).

## Preserved attempts

The owner executed immutable source/bundle `07cf5e1eb0d81787648f6e40abcda793dfcfdfed`.
Attempt `e888975a-207a-473f-a442-2a2895f02347` is independently retained as
`INVALID_HOST_PREFLIGHT / INVALID_PARTIAL_STATE_REVIEW_REQUIRED`; its cleanup stopped
the synthetic backend and retained the lease, created no reverse, and performed no
tablet mutation. Host diagnostic `1a2ba2bb-bd97-4419-83f5-c5da18c84023` is durable.
The attempt-file aggregate SHA-256 is
`92086d456a5e7417ec5bb111a8d7cfdb114d49ebe6c23060c287f9219b51dea1` and the host
diagnostic SHA-256 is
`a176a66d452e691aec1edf6abdd185dc40be90e7e7e8ac1c335db8599433ea8d`.

Historical attempt `d9157ae6-a6ff-4849-919f-c8f13fe08f7e` remains independently
`INVALID:PAIRING_TIMEOUT / cleanup UNVERIFIED`; its non-lock attempt-file aggregate
SHA-256 remains `5e2675281c33d586af58e4cf42da990170dd9dbf28784b7468643356376fabee`.
No row or result in either attempt was rewritten.

Three immediately preceding source-07cf5e1 attempts stopped independently at
`DOCKER_ENGINE`; none supplied or replaced the later resume review.

## Recovered facts

No protected credential value, QR payload, device serial, private file content or
unknown filename was retained or emitted. A host-only restart of the exact retained
synthetic backend projected counts only and stopped cleanly: one owner, one household,
zero devices, one consumed historical session, no saved-device pointer and a valid
compatibility-digest shape.

| Fact | Recovered value | Basis |
| --- | --- | --- |
| provenance | true | exact immutable bundle/provenance passed before review |
| owned | true | retained backend: one owner + one household |
| compatible | true | backend admitted the retained lease and returned a 64-hex digest |
| reverseAbsent | true | fixed reverse-absence assertion precedes resolution; result says NOT_CREATED |
| historySafe | true | exact d9157ae6 history was accepted and named by durable RESUME_REVIEW |
| metadataKnown | **UNSPECIFIED** | old runner discarded the metadata failure boundary |
| noUnknownFiles | false | necessary value at resolution; otherwise the recorded empty LAB state selects ENROLL |
| package | LAB | d9157ae6 verified installation before later admitted stages; every later attempt had zero mutation |
| historicalPartial | true | durable review binds d9157ae6 and preserves INVALID/UNVERIFIED |
| backendDevice | false | physical result and retained backend both report none |
| savedDevice | false | sanitized DPAPI projection and retained backend agree |
| savedMatches | false | no saved pointer and no backend device |
| identity | false | value recorded by physical result; proof strength depends on metadataKnown |
| pending | false | value recorded by physical result; proof strength depends on metadataKnown |
| accounting | false | value recorded by physical result; proof strength depends on metadataKnown |
| credentialUsable | false | no backend device |
| policyConsistent | false | no backend device |
| noPolicyOrReport | true | no backend device |
| resetAttributable | false | noUnknownFiles was false |

**Exact recoverable failed predicate:** `NO_UNKNOWN_FILES` was false. The complete set
is not recoverable from preserved bytes: it is either `[NO_UNKNOWN_FILES]` or
`[METADATA_KNOWN, NO_UNKNOWN_FILES]`. Source-07cf5e1 initialized both booleans false,
then persisted neither. Its `Get-PrivateMetadata` also collapsed any execution/parser
failure to `status=UNKNOWN`. Therefore preserved evidence cannot distinguish a known
metadata result with an extra durable file from a metadata read failure. Naming a file
or choosing category A/B/C/D would be a guess, so the allowlist is unchanged.

`LAB_PACKAGE_UNPAIRED` remains **INFERRED**, not established: package/backend/local
state is consistent with it, but its mandatory metadata predicates were not proven.
There is no saved-device orphan to reconcile or clear.

## Bounded correction

The resolver now returns and the durable RESUME_REVIEW persists `reviewReason` plus
ordered `failedChecks`. Allowed values are PROVENANCE, OWNERSHIP,
BACKEND_COMPATIBILITY, REVERSE_ABSENT, HISTORY_SAFE, METADATA_KNOWN,
NO_UNKNOWN_FILES, PACKAGE_PROVENANCE, SAVED_DEVICE_ORPHANED and
POLICY_STATE_AMBIGUOUS. The final sanitized runner JSON carries the same resolution.
Multiple prerequisite failures are retained rather than reduced to the first boolean.

A saved pointer with no backend device is now explicitly
`SAVED_DEVICE_ORPHANED` and remains non-mutating INVALID. No automatic pointer clear
or backend deletion was added because that condition was not observed here. Exact LAB
with every prerequisite true still selects `LAB_PACKAGE_UNPAIRED / ENROLL`; metadata
unknown, extra durable files, old/foreign package, ownership/compatibility failure and
policy ambiguity remain fail-closed. Synthetic read-only failures assert unchanged
backend/metadata objects and an empty mutation journal.

## Device-free validation

- Native local Windows PowerShell 5.1: resume/journal **97 checks PASS**; actual
  extracted read-only gate **99 PASS**; host preflight **43 PASS**; reuse **43 PASS**;
  prerequisites **72 PASS**; metadata/update review **84 PASS**; DPAPI/lock/private
  pipe lease **20 PASS**. Every suite reports `DEVICE=NOT_INVOKED` or equivalent.
- Node lease/compatibility: **19/19 PASS**, including the explicit immutable-freezer
  blocker. Host QR payload/BOM/bounds: **5 PASS**, device not run.
- Isolated KR-003 Gradle: **BUILD SUCCESSFUL**, 274 tasks (6 executed, 268 up-to-date).
  Build audit: **24/24 JVM**, merged debug/release permissions and DEX isolation PASS.
- Python host observers: **3 + 4 PASS**; the update-review suite used native
  `powershell.exe` because `pwsh` is not installed in WSL.
- One local native QR-window invocation stopped independently at
  `WINDOW_VISIBILITY ... TOP0` after 11 checks. It made no device call. This is a
  current interactive-session/topmost failure, not a passing result and not evidence
  against the metadata correction. Native PS5.1 and PS7 QR tests remain mandatory in CI.

Full SQL/backend, PS5.1/PS7, Android build/lint/security/privacy and required CI must
pass on the final source before this bounded diagnostic is complete. Passing them
does not unblock the physical oracle while the historical metadata predicate remains
unresolved.

## Gate

`PRODUCT_PHYSICAL_ORACLE = BLOCKED`. Source/bundle 07cf5e1 is retired and must not be
rerun. No replacement bundle or PowerShell command may be published until a future
authorized read-only observation establishes whether METADATA_KNOWN also failed and,
if applicable, classifies any extra file from structural metadata. No Samsung command
was executed in this diagnosis.
