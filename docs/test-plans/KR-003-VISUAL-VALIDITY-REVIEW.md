# KR-003 visual-channel validity review — 2026-09-10

Subsequent owner-authorized work adds a separate [synthetic exact-content cache prototype](KR-003-VISUAL-DEDUP-PROTOTYPE.md) and commits this preserved review with it. The prototype does not modify v1 classifier semantics, immutable artifacts or any finding below. References to uncommitted status and module hashes below describe the review's original stopped state, not the later prototype commit.

## Scope and disposition

**OBSERVED:** review began at clean HEAD `630eaad4cfa84d40aedf8ead6f93c593f1c212c3`, not the stale conversation recap's `8416583`. Source `0596173c0086fcf76fcf46c7f98dabbc6ba8a874` and its immutable bundle are unchanged. No physical media or device was accessed. Tests use synthetic feature grids only.

**Disposition:** `0596173` is suitable only for exploratory capture-transport/cadence and phase-group-difference measurements. Its emitted PASS does **not** independently recognize the expected restriction surface, establish continuous visibility, or authorize replacement of any human checkpoint. No physical execution is requested. OD-41 permission for local lab capture remains approved; acceptable missed-interruption tolerance and demonstrated checkpoint sensitivity remain **UNSPECIFIED**. Production prohibition, fixture independence, OD-39, historical verdicts and zero pooling/resume remain intact.

## Temporal finding

**OBSERVED:** `Get-KRVisualTemporalMetrics` uses host request start/end intervals, not native display timestamps. For adjacent requests it computes `next.End - previous.Start`; it also includes window-edge uncertainty. `ObservedSpanMillis` is `last.End - first.Start`, not observed continuous time. `SpanCoverageRatio` divides that span by the requested window. Neither the span nor the sum of request durations is a measure of continuously observed display time.

The 1,500 ms cap and 0.90 span threshold first appear in implementation commit `d303082`. Repository decisions and the implementation's accompanying protocol provide no empirical sensitivity study, Android guarantee, or owner-approved missed-failure budget supporting these numbers. They are implementation-selected benchmark filters, not accepted visual safety tolerances. The ten-second observation requirement does not approve 1.5-second blind spots.

Synthetic baseline: restricted window `[3900,14500]` ms; 11 requests `[4000,4100]`, `[5000,5100]`, …, `[14000,14100]`. Result: 10,100 ms span / 10,600 ms window = **0.952830**, 100 ms request uncertainty, 1,100 ms reported worst gap.

| Synthetic timeline / capture sequence | Current result | Demonstrated meaning |
| --- | --- | --- |
| Ordinary → expected restricted samples → ordinary | PASS | Two self-fitted groups separate and ordinary round trip repeats |
| Ordinary surface substituted for one decoded restricted sample | FAIL | This particular sampled disappearance is detectable |
| Interruption `[6500,6800]` entirely between requests | PASS, identical observations to uninterrupted timeline | 300 ms interruption is not observed; high span ratio does not establish continuity |
| Sparse requests at 4000, 7000, 10000, 14000 | INVALID | Large request-gap filter works |
| Fewer than three restricted observations | INVALID | Truncation filter works |
| Static restricted samples with advancing requests | PASS | Repeated images alone are not dropped frames |
| Capture freezes only during restricted phase, then resumes before CLEAR samples | Same PASS inputs as static content | Endpoint transitions cannot establish within-phase freshness |
| Frozen ordinary content across both transitions / reused timestamps | INVALID | Existing separation/timestamp checks detect these narrower faults |

**INFERRED, conditional only:** if each request yields a fresh instantaneous representation within its interval, the classifier reliably recognizes the interruption, and it persists wholly within the tested window, an interruption strictly longer than the maximum conservative request gap must intersect a sample. This is a sampling argument, not a demonstrated physical sensitivity guarantee. A shorter event can still be detected if sampled. At the boundary, endpoint timing matters. The serialized `DefensibleInterruptionDetectionBoundMillis` overstates the evidence: it is a conditional request-gap statistic. Minimum defensibly guaranteed physical-display interruption detection duration is **UNSPECIFIED**, including freshness, spatial/downsampling sensitivity and display/capture correspondence.

## Reference-independence finding

**OBSERVED:** `Get-KRVisualClassification` computes `restrictedPrototype = centroid(restricted)` and evaluates those same frames against that prototype. There is no independent expected-restriction reference and no unknown-third-surface rejection radius. Fixture state establishes focus/input effects, not the visual identity of the surface that displaced it. Candidate telemetry cannot supply that missing visual ground truth.

Added counterexamples against the unchanged implementation:

- A synthetic unrelated nonblank alternating-color surface replaces all 11 restricted observations: **PASS**, all 11 labelled RESTRICTED despite distance greater than 0.1 from the synthetic expected restriction.
- The same wrong surface replaces the middle 9/11 observations, retaining correct first/last restricted images: **PASS**. The contaminated reference still accepts both populations. Even correct endpoints do not protect against sustained wrong imagery.
- Existing midpoint ambiguity and black/blank cases remain **INVALID**; these protections do not reject a confidently separated third class. Broad spatial change rules reject small-only differences but do not identify what occupies the screen.

Thus the demonstrated visual PASS means only: repeatable ordinary-phase imagery differs sufficiently from imagery in the phase called RESTRICTED, and every evaluated sample agrees with the self-fitted two-class partition under the current numeric filters. At runner level PASS additionally requires accepted capture/journal checks, fixture input/focus controls, candidate corroboration and verified cleanup/restoration. Those independent software controls remain useful; they do not repair the visual circularity. Capture transport on the physical Samsung remains **UNSPECIFIED / Not run** for this artifact. No historical verdict is changed.

## Smallest justified correction and next candidate

Immediate correction is documentation/scope plus executable falsification tests, not retuning thresholds or rebuilding an immutable artifact. Existing result names are preserved as emitted identifiers, not endorsed semantic proof. No human checkpoint may be replaced by a PASS from this bundle.

Recommended bounded future classifier correction, **not implemented or newly owner-approved here**:

1. Establish separate, owner-verified local ordinary and expected-restriction reference acquisitions for the exact display/configuration; bind their hashes and provenance before the evaluated attempt. Neither candidate state nor phase membership defines visual correctness.
2. Freeze reference features, spatial integrity requirements and absolute acceptance/rejection thresholds before held-out observation. Never update them from the hold under test. Keep images and image-bearing features local-only; only hashes/metrics/classes leave local analysis.
3. Validate on disjoint acquisitions and negative third surfaces, sustained substitutions, partial disappearance and ambiguity. Require an UNKNOWN rejection region, not just nearest-of-two. Held-out splitting alone is insufficient if both sets share phase-derived wrong labels. A small marker does not prove full-screen correctness.
4. Separately agree the required interruption sensitivity and validate timing/freshness with controlled transitions throughout the channel test; do not select a tolerance merely because the capture method passes it.

Bounded video is a better **candidate to evaluate** for shorter blind intervals: Android documents `screenrecord` as a bounded MPEG-4 display-recording utility, with device/resolution/rotation limitations. It does not promise every physical display frame is represented. [Official Android ADB documentation](https://developer.android.com/tools/adb#screenrecord), checked 2026-09-10. A future local test would inspect native decoded presentation timestamps, missing/truncated intervals, alignment uncertainty, controlled liveness transitions, independent fixture agreement and capture interference. No nominal-FPS resampling, duplication or interpolation could establish completeness. Video does not fix circular references. No video implementation or device capability claim is made in this review.

After independent semantic and temporal calibration, only the normal/post-run ten-second **visual persistence portions** could be candidates for substitution with the fixture oracle. Currently **none** are demonstrated replaceable. Home exercisability/unavailability, OD-39 physical Home action versus synthetic Path B, Settings/recovery, emergency/accessibility, keyguard and other unresolved physical-operability/safety checks remain outside that scope. No zero-human qualification claim is justified.

## Verification

Native Windows PowerShell 5.1: 58 assertions passed, including 21 added limitation assertions against unchanged v1. Existing sampled-disappearance, ambiguity, blank, truncation, gaps, stale timestamps, frozen transitions and cleanup/primary-result tests still pass. Tests are already included in the existing PowerShell 5.1/7 CI suite. PowerShell 7 is not installed on this local host; this review does not claim a new PS7/CI run. No unchanged Android build is repeated.

All four focused Node visual-ingestion/security tests passed, as did `node tools/validate.mjs` and `git diff --check`. The local and immutable classifier SHA-256 both remain `bc68f0907fe6724e21de66a1209afb56f6b135f1bd4cf454287378b9e2afd5fb`; bundle manifest SHA-256 remains `c69c2d0aa76574afee874fa0b01e89b4f4a92588816f99a20b8178573e357af7`. PR #16's one obsolete visual bundle path was corrected to `0596173`, preserving the rest of its body and appending the restricted review scope. Review documentation/tests remain local uncommitted changes; no new source/bundle publication or CI trigger was performed.
