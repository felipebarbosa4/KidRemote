# KR-003 reference enrollment and video characterization

- **Goal:** Prepare one excluded owner-local session enrolling two independently confirmed references before a separate held-out video sequence.
- **Context:** Published `b1c4a1b` preserves the circular-reference and temporal-limit findings. Its CI run 34521866149 passed, including native Windows PowerShell 5.1/7 and required Android isolation. Windows FFmpeg/ffprobe 8.1.2 are available without host changes.
- **Constraints:** No agent ADB/device/private-media operation; no new full qualification; at most two owner confirmations; references frozen before held-out evaluation; unknown remains invalid; no new similarity or missed-interruption tolerance; no network/navigation mutation, production capture, historical pooling or KR-004 work.
- **Done when:** Reference provenance, decode/timestamp handling and cleanup are synthetically checked; either one tested immutable diagnostic is ready or a demonstrated prerequisite failure is explicitly recorded without publishing an unready artifact. `CheckpointReplacementAuthorized=false` in all cases.
