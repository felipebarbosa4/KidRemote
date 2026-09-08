# Mi 8 UiAutomation transport denial — 2026-09-06

- **Goal:** Classify the owner-run transport failure from mounted evidence without another physical run.
- **Context:** Shell input was already denied; the independent instrumentation probe was the next SIM-free experiment.
- **Constraints:** Preserve the original directory, separate transport from enforcement, no device action or configuration change.
- **Done when:** Exact failed stage, fixture outcome, cleanup evidence and next bounded experiment are recorded.

Read directly from `C:\platform-tools\kr003-uiautomation-transport\transport-20260906-233234-db34424b` through `/mnt/c`.
All five files were present and retained unchanged. Node transport ingestion passed. Owner-local date is September 6;
recorded UTC interval is `2026-09-07T03:32:34.8170199Z`–`2026-09-07T03:32:54.1841099Z`.

Source: `8b16c1b53e5c76c5303492d49f1ddba63a3bfbbd`.
Probe SHA-256: `1c859cc709cc8f2ef32333397be9d584405474ae93a77436c8f8e40e12f0fd43`.
Fixture SHA-256: `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`.

## Established sequence and classification

All recorded ADB operations, including `UIAUTOMATION_TAP`, returned exit 0 / stderr class NONE. The exception was caught
inside the probe, not by the host ADB wrapper. Matching request `285928958` returned:

```text
Stage=DOWN Outcome=SECURITY_EXCEPTION
DownAccepted=false UpAccepted=false Cleanup=FRAMEWORK_FINISH
```

The fixture's before/after state was focused, resumed and probe-ready, with the same process instance `66790`, coordinate
`540,1956`, one focus gain and zero losses. Counter remained **0 → 0**. Its monotonic elapsed values were `67191 → 71619`.
The low elapsed values are not evidence of who rebooted the phone or of any setting change; those circumstances are **UNSPECIFIED**.

Primary recorded result remains **INVALID:UIAUTOMATION_INJECTION_OR_CLEANUP**. More precise interpretation:
**DOWN injection denied by SecurityException; framework finish returned; independent input delivery absent**.
The generic reason must not be rewritten as an established cleanup failure. UP acceptance was false; a separate UP exception
was not retained because the probe preserves the first failure. Internal MIUI permission-check implementation remains **UNSPECIFIED**.
The earlier owner-observed disabled SIM-gated security switch strongly supports, but does not prove, the exact internal explanation.

No candidate restriction was armed/cleared, no radio/permission/settings change was performed, and no Q7 sample or human
qualification checkpoint occurred. This is not an enforcement failure or pass. Original evidence is not modified.

## Evidence fingerprints

| File | SHA-256 |
| --- | --- |
| fixture-after.json | `9970cc3d3adf7a8af56267485117780e59565f12522b1297686d6bf134246869` |
| fixture-before.json | `61b91d4b4fe7c743994c228155b3463cde391cb6c2fe5baa373f6f74b05eed27` |
| operations.json | `261e2064fae14add8970062ef79e78960f215eca040ed5966b79a2238653b786` |
| probe.json | `52e8b10f60d0e88213beb31bf8d2189f78fa12774dbd268a6c481de4927f85e0` |
| summary.json | `23fb217bc9822f34eb7c9197ec8c5fb9f13deb2a565ea54a16da008bf760a71d` |

At this checkpoint the next bounded experiment was the [Monkey touch-class transport](../KR-003-MONKEY-TRANSPORT.md). It subsequently returned
[DOWN `SECURITY_EXCEPTION`, zero taps and verified cleanup](KR-003-MONKEY-DENIAL-2026-09-07.md). Q7 is blocked on the unchanged Mi 8.
KR-003 stays Open/In Progress; PR #16 draft; KR-004 untouched. No SIM-free setting bypass or Play acceptance is claimed.
