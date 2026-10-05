# OD-51 partial preparation reconciliation

- **Goal:** Resolve package and synthetic enrollment state independently in PR #24's single owner runner, without changing the product or independent fixture oracle.
- **Context:** Source e8be9cf; attempt d9157ae6-a6ff-4849-919f-c8f13fe08f7e ended INVALID:PAIRING_TIMEOUT after ENROLLMENT_ADMITTED, cleanup UNVERIFIED. Exact lab APK replaced the old package. No policy/Lock/Unlock admission exists.
- **Constraints:** No physical command in this task; no interop repair. Preserve old journals/results/bundles. Metadata only; never decrypt/read credentials. Exact ownership and backend compatibility precede reuse. Ambiguous or potentially restricting state fails closed. Only OD-50 child data and exact synthetic pairing state may be reset after durable admission. QR presentation and release bytes unchanged.
- **Done when:** Explicit package/enrollment resolver, immutable separate review, compatible lease handling, bounded reset/resume/reuse wiring, native and backend failure tests and CI, honest evidence and one new frozen command if ready. No physical acceptance claim.
