# OD-51 read-only metadata probe pull correction

- **Goal:** Correct the diagnostic probe's child-APK pull validation so normal bounded
  ADB progress on stderr does not hide an otherwise valid read-only provenance check,
  while every failure reports a sanitized stage and reason.
- **Context:** Owner attempt `78bf058e-280f-4ee1-9384-a51a75a395e5`, from immutable
  probe source `bcac31838720a8aee77488ccf4b1ca9ad4b7929e`, stopped after exact
  configuration/reverse validation with `ADB_READ_FAILED` and a deleted host temporary
  APK. The preserved result does not distinguish nonzero exit, stderr or output bounds.
- **Constraints:** Preserve that attempt and all earlier physical evidence; no Samsung,
  emulator or physical ADB execution; do not broaden the command allowlist or weaken
  exact local path, regular-file, non-reparse, size, device-hash or signer validation;
  never expose raw stderr, serials or private contents. Freeze only a replacement
  read-only diagnostic probe, never a product-slice bundle.
- **Done when:** Dedicated pull validation and typed failure stages pass parser/static,
  native fake-ADB PowerShell 5.1/7, ProductRuntime, ACL/DPAPI, build/lint/security/privacy
  and required CI; a new immutable probe is frozen; the product oracle remains blocked
  and no physical execution has occurred.
