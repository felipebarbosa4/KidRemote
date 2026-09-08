# KR-003 generic active-oracle calibration

- **Goal:** Determine whether one exact transport-capable Android configuration can support the independent active oracle before any 100-cycle qualification starts.
- **Context:** A fixture-only transport PASS is necessary but cannot show that the candidate blocks input or stays connected. Q7's Mi 8 specialization remains blocked and unchanged; a new device requires fresh calibration.
- **Constraints:** Run only after a preserved generic transport PASS; exact disposable candidate/fixture hashes; no network/configuration mutation, screenshots, UI nodes/text/content, raw identity/history, destructive action, result pooling or qualification loop.
- **Done when:** One unblocked tap increments the fixture exactly once, one armed expiry produces a ten-second blocked hold with input/focus denial and candidate service continuity, one operator agreement response is preserved, cleanup is verified, and zero qualification rows exist.

## Bounded workflow

The separate calibration bundle performs only this sequence:

1. verify bundle integrity, ADB authorization and the exact installed/pulled APK hashes;
2. read the exact configuration again and require the candidate's Usage Access, Accessibility service, heartbeat and eligible-use health;
3. clear only the disposable lab timer, foreground the independent fixture and require one shell tap to increment its counter exactly once (**unblocked positive control**);
4. arm one fresh ten-second disposable allowance/revision while the fixture is visible;
5. wait for candidate attachment, then inject 20 equivalent taps over at least ten seconds and require zero fixture increments and zero focus regain (**blocked negative control**);
6. require no candidate trace gap, process replacement, permission loss or new service connection from the pre-arm baseline through the hold (**candidate service continuity**);
7. ask the operator once whether the visible restriction agreed with the automated result, recording P/F/I (**physical agreement check**);
8. clear only the lab timer, verify restriction release without altering the calibration latency sample, write a sanitized summary and stop with `QualificationSamples=0`.

Candidate telemetry is corroborating evidence only. The fixture has an independent package/UID and no shared storage or callback with the candidate. It exposes only its generated instance, focus/resume/focus-gain counters, touch counter and its own probe coordinate. Neither component reads node text, content, screenshots or package history.

## Result contract

- **PASS — `PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY`:** all four technical controls and the one physical agreement check pass, cleanup is verified, and exactly one excluded calibration sample is retained.
- **FAIL:** visible disagreement, delivered blocked input, focus regain, missing block, permission/service loss or cleanup failure. Stop before qualification.
- **INVALID:** transport, hash, configuration identity, evidence correlation or operator observation was unavailable/uncertain. Stop before qualification.

A PASS permits preparation of a new configuration-specific 100-cycle qualification bundle; it does not authorize that run by itself and is never counted among its 100 rows. The exact required OS/API/OEM matrix mapping must be recorded first. Human-only rendering/safe-surface residual risks remain separate even if calibration passes.
