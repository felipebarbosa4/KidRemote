# OD-51 current read-only metadata observation

- **Goal:** Prepare one immutable, owner-operated Windows probe that records the current authorized Samsung lab configuration, APK provenance, reverse absence and application-private file structure needed to decide whether a later product-slice bundle may be considered.
- **Context:** Historical attempt `e888975a-207a-473f-a442-2a2895f02347` remains immutable with `noUnknownFiles=false` and `metadataKnown=UNSPECIFIED`. This probe creates independent current evidence and never backfills that attempt.
- **Constraints:** One authorized non-emulator target; only `dev.kidremote.child.unassigned.debug` private metadata; no device/backend/app-private write, install, uninstall, clear, reverse mutation, launch, input, policy call, screenshot, content read, database query, preference read or historical-journal write. Unexpected output is limited to safe structural paths, regular-file size and 64 entries.
- **Done when:** PowerShell 5.1/7 parser, command-allowlist, metadata fixture, native entrypoint, no-mutation, catalog, build/lint/security/privacy and required CI checks pass; a committed CI-validated immutable diagnostic-only bundle is frozen; physical execution remains not run and `PRODUCT_PHYSICAL_ORACLE` remains blocked.

