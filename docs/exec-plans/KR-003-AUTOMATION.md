# KR-003 qualification automation

- **Goal:** Ingest the completed Mi 8 checkpoint and prepare reproducible qualification with minimal operator work.
- **Context:** Fix `de941a9`; ten completed owner-observed cycles; Windows ADB is an owner-assisted execution boundary.
- **Constraints:** KR-003 only; no host changes or device execution from WSL; no invented physical passes; release controls/trace absent or no-op; no destructive execution.
- **Done when:** Evidence is ingested and published, qualification semantics reconciled, debug controls and runner tested, release isolation audited, remaining matrix work queued, and a single Windows command is ready.

## Execution

1. Validate mounted CSV and trace, preserve hashes/results and evidence limitations; commit/push.
2. Resolve the 100-sample contract from physical protocol, KR-003, ADR-0002, matrix and capacity definitions.
3. Implement debug-only lab control/metrics and a fail-closed qualification runner; test with synthetic failures and build both variants.
4. Package exact APK/source/runner/protocol hashes and prepare owner execution; no physical qualification is run in WSL.
5. Record the remaining automation/device/policy roadmap and synchronize KR-003 issue/Project without closing it.

## Current findings

The mounted observer CSV has exactly ten sequential unique cycles with all five recorded outcomes successful. The trace has only main/system
buffer headers, with an empty stderr file. This is a trace-collection gap whose cause is **UNSPECIFIED**, not evidence of absent attachment.
The next runner must verify direct telemetry availability before arming and preserve every failed/invalid attempt.
