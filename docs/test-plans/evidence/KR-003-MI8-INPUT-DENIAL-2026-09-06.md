# Mi 8 shell input denial and SIM-gated setting

- **Goal:** Preserve machine-observed input denial and owner-observed configuration without overstating MIUI internals.
- **Context:** Three Q7 preflights stopped before sample 1. The subsequent tiny shell-transport probe isolated the rejection.
- **Constraints:** Preserve original files, no setting workaround or new physical execution, no qualification claim or KR-004.
- **Done when:** Facts, inference and next bounded diagnostic are explicit and reproducible.

## Mounted evidence

Read directly from `C:\platform-tools\kr003-oracle-transport\transport-20260906-224820-43775fd1`:

| File | SHA-256 |
| --- | --- |
| `operations.json` | `f6d16444d0f972ee8917607548baf9324d62cd0fcbc8fe0bb2d2afbcaa8eaf60` |
| `summary.json` | `6f787a331ee8e59f15b6697626c7a4a6fdde15cf0a3e40fdaa759048308262b4` |

Source `95937b95d585b93f9878f55503f224c61c590a26`; start/end UTC 2026-09-07 02:48:20.4357262 / 02:48:25.3770243.
Device, fixture installation/open and both fixture-state queries succeeded. `INPUT_TAP` returned exit **1**, class **SECURITY_EXCEPTION**.
Summary: `INVALID:ADB_OPERATION_REJECTED`; receiver worked; before taps 0; after taps null; no verified increment; zero Q7 samples.
Restriction, radios, permissions and destructive-action flags are all false. Original files and three earlier INVALID runs remain untouched.

## Owner's physical configuration evidence

Exact device: Xiaomi Mi 8 / MIUI Global 12.0.3 / Android 10 API 29 / dipper.

- Normal USB debugging: enabled.
- USB debugging (Security settings): disabled.
- Observed option description: "Allow granting permissions and simulating input via USB debugging".
- Attempt to enable it displays a requirement to insert a SIM card.
- This lab phone currently has no SIM. No successful setting change is reported.

The setting's visible wording plus the exact rejected input operation strongly support the disabled security switch as the input-denial mechanism.
The private internal MIUI code path has not been inspected and remains **UNSPECIFIED**. No other developer option is indicated by the evidence.
No verified official method to enable this exact toggle without a SIM was located; no speculative settings writes or security-app modification
were performed. A SIM is not requested for the next diagnostic.

## Diagnostic disposition

At this checkpoint the separate [UiAutomation transport probe](../KR-003-UIAUTOMATION-TRANSPORT.md) was the next unblocked fixture test.
It subsequently returned [DOWN `SECURITY_EXCEPTION` and zero fixture taps](KR-003-UIAUTOMATION-DENIAL-2026-09-06.md); the bounded Monkey fallback
then returned [the same denial class and zero taps](KR-003-MONKEY-DENIAL-2026-09-07.md). All three tested transports are therefore denied on the
unchanged Mi 8 configuration. KR-003 remains Open/In Progress; Q7 remains halted there; PR #16 remains draft; KR-004 is untouched.
