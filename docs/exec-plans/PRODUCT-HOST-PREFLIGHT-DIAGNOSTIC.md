# OD-51 host-preflight diagnostic

- **Goal:** Diagnose the preserved owner failure and make the next single-command host gate actionable.
- **Context:** `871fcfa` returned INVALID_HOST_PREFLIGHT / UNSPECIFIED before device mutation; PR #24 remains draft.
- **Constraints:** Preserve frozen bundle and historical verdicts. No physical runner, ADB, Samsung, WSLInterop repair, unrelated resource cleanup or product changes.
- **Done when:** Reproduction and uncertainty are recorded; early diagnostics and backend stages are tested on native PS5.1/PS7; required CI passes; a new immutable bundle replaces the old command.
