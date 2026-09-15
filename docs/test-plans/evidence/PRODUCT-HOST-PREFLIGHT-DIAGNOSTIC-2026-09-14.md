# OD-51 owner host failure — independent record

## Owner attempt, preserved verbatim as sanitized fields

Source/bundle `871fcfa473b847f83ea56d057b2406491911fd8c`:

```json
{"hostValidated":false,"hostFailureStage":"UNSPECIFIED","primary":{"status":"INVALID","reason":"INVALID:INVALID_HOST_PREFLIGHT","cleanup":"UNVERIFIED"},"backendCleanup":"NOT_STARTED","reverseCleanup":"NOT_CREATED","labRecovery":"NOT_REQUIRED"}
```

**OBSERVED (owner report):** one execution, no Samsung mutation. Original INVALID and
UNVERIFIED cleanup remain unchanged. No attempt UUID or timestamp was retained in the
provided output; neither is fabricated here.

**OBSERVED (host filesystem inspection):** old manifest SHA-256
`b1cee5b0347b7b4d2435d1a548546d38d9b084fb1076d886195dcacf1b72501d` matches;
all 1,089 file hashes match. `product-slice-attempts` exists but is empty;
`physical-lab` does not exist. The known OD-50 host-validation directory contains no
files. No exact attempt journal/result could be recovered there. No old bundle file
was changed. Docker resource inventory remains **UNSPECIFIED**: no native Docker
execution through unavailable WSLInterop, no adoption, prune or deletion.

**OBSERVED (device-free reproduction):** the old ordered module imports remove
`New-ProductJournal` and `Read-ProductJournal` from caller scope, while
`Invoke-ProductHostGate` remains available. Nested `Import-Module -Force` reloads the
same modules after their commands were imported by the entrypoint. The existing frozen
module test only checked imports/parse, not command availability or journal creation.

**OBSERVED:** executing only the unchanged old entrypoint prefix through journal
creation, against all verified frozen bytes and an isolated temporary host-state root,
produced `CommandNotFoundException`, command `New-ProductJournal`. The prefix excluded
all backend and ADB callbacks. This was a diagnostic prefix, not a physical-runner run.

**INFERRED:** this deterministic pre-journal defect matches the empty attempt directory
and backend NOT_STARTED result. The corresponding stage is JOURNAL_READY. The exact
owner exception was swallowed and is **UNSPECIFIED**, so the reproduced cause is not
represented as recovered owner exception evidence. Docker Desktop being stopped is
**NOT ESTABLISHED**; the previous Docker advice was generic, not a diagnosis.

## Bounded correction

Load shared modules without forced reload in the owner dependency graph. Extend frozen
module tests to require nine entrypoint commands and actually create/read a journal.
The entrypoint now assigns a typed stage before initial bundle/runtime/ADB/journal work;
backend errors preserve typed stages through the PowerShell gate and private Node pipe.
Raw native errors, credentials, serials and private paths are never emitted.

An independent create-new UUID host diagnostic is fsynced and atomically renamed under
`KidRemote/product-host-failures`, including errors before mutation journal creation.
A persistence failure explicitly requests preservation of the console JSON. Existing
mutation journals retain their original verdict and separate cleanup. A failed host
attempt cannot authorize any device mutation. Unknown/foreign/partial leases remain
review-only; no new automatic deletion or adoption path was added.

## Validation record

An initial reproduction command used a relative PowerShell module path without `./`;
imports failed, so that attempt was invalid as causal evidence. Repeating with absolute
paths reproduced the actual missing journal commands. This failed probe is preserved
here rather than pooled into the valid reproduction.

Local and required CI results are recorded in the delivery record once complete.
No physical runner, ADB command, emulator or backend was started locally in this task.
The old `871fcfa` owner command is retired. A replacement is ready only after current
source CI passes and a new immutable manifest is frozen. This never constitutes
physical enforcement PASS.
