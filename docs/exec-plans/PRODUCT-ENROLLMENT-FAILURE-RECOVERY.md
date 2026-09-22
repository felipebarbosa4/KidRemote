# OD-51 post-preflight enrollment failure recovery

- **Goal:** Diagnose the immutable product-slice attempt from source
  `863a977407b1f7d5a072b1e6284de0847a5ed0c4`, make every enrollment failure
  stage/code explicit, reconcile its exact abandoned synthetic pairing session,
  and prepare one replacement owner runner if all safety gates pass.
- **Context:** Owner attempt `28756da0-cbcf-410b-9957-d7aade9afcf4`
  passed host validation and admitted enrollment, then returned an untyped host
  or transport failure before displaying `QR_WINDOW_READY`. The retained backend
  is the task-owned OD-51 persistent synthetic lease. PR #24 remains draft and
  KR-003/KR-010 physical acceptance remains open.
- **Constraints:** Do not execute Samsung/ADB or an emulator; do not repair
  WSLInterop; do not rewrite physical results, journals, reviews, diagnostics, or
  prior attempts; do not log QR/JWT/credentials/serial/raw stderr; do not weaken
  QR visibility or provenance gates; cancel only an exactly reviewed, task-owned,
  unconsumed pairing session through `finish_pairing`; never delete an enrolled
  child or infer cleanup as verified.
- **Done when:** The exact journal/backend facts are recorded; enrollment stages
  and QR rendering have bounded typed failures; an immutable source-controlled
  review admits only the exact failed attempt and exact backend residue after
  live package/reverse/private-state checks; PS5.1/PS7, QR, review/journal,
  lease/backend, SQL/RLS, JVM/Gradle/security/privacy/release-isolation and CI
  pass; historical hashes remain unchanged; and a new immutable bundle is frozen
  without physical execution.

Stopping point: return one owner PowerShell command and stop before Samsung
execution.
