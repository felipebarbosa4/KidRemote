# OD-51 QR presentation

- **Goal:** A future scan instruction requires an actual visible, live Windows QR form.
- **Context:** The owner reached camera scan with no visible host QR on source 3693034; PR #24 remains draft.
- **Constraints:** Host UI only; unchanged QR protocol/product/scanner, journal/lease gates and APK. Preserve the timeout attempt and immutable bundles. No physical execution during validation.
- **Done when:** Native PS5.1/PS7 visibility/lifetime/failure tests and required CI pass, a new immutable bundle is frozen, and any prior-attempt/host-execution blockers are reported without bypassing them.
