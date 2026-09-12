# Test7 runtime validation: Analyzer speed candidate

Session: September 11, 2026, completed at 20:48:09 America/Denver.
Game: Upload Labs, Godot 4.6.1, AAC v0.1.15-test7, ASM test20.
Preserved local evidence: `C:\Dev\UploadLabsRecovery\godot-test7-consumer-run1.log`.

## Passed in this session

- Test7 loaded and reached ready (lines 149, 344), without an AAC script error.
- The user disconnected `smart_thread_manager0/Output -> analyzer5/Speed`, target `166a1bbfd6c9` (lines 2673–2676).
- That zero-required input became an eligible target with 15 verified candidates and `reason='unserved_speed_input'` (line 2706).
- At sample 4, the Thread Manager ranked first at score 60, ahead of the next source at 58. Its actual manager adjustment was +4 with `manager_validation='runtime_validated_projected_headroom'`, projected ratio 6.4984429374, and positive projected target demand (lines 2726–2729). Total score also includes existing player preference; +4 is the isolated manager component.
- Three samples while disconnected recorded 11 manager candidates with 11 nonzero applied adjustments. Reconnection removed the Analyzer candidate and returned the count to the 10 other manager candidates (samples 7–8).
- All 16 manager records across eight samples had matching raw demand mirrors and zero raw reprojection mismatches/unavailable results.
- Four graph revisions stayed structurally clean: 472, 472, 471, 472 edges; zero dangling, nonreciprocal or resource mismatch counts.
- Post-startup FPS observations after graph revision 2 ranged from 84 to 120 (mean 112.65). This is observed telemetry, not a controlled performance benchmark.

## Limits and remaining coverage

- The sole script error was the previously observed base-game `res://scripts/ad_prompt.gd:5` undeclared `Ads` error (lines 371–372). Other game startup/shutdown warnings are not being claimed resolved.
- GPU manager adjustments also executed for already-unserved GPU synchronizer inputs, but their projected incremental finite demand was zero. These are not evidence for a positive-demand GPU consumer disconnect/reconnect test or for throughput improvement.
- The zero-required fix exposes 10 pre-existing CPU/GPU manager candidates in this save before the Analyzer is disconnected. Candidate totals are therefore higher than test6 by design; live connection checks and guarded explicit Accept remain in place.
- No AAC Accept/Undo action was tested in this session. Reconnection was manual and was observed by the preference model.
- The Analyzer candidate-generation and projected-scoring gate passed. This is not a claim that every manager/resource scenario or the full release acceptance gate has passed. No GitHub publication or merge was performed.

## Follow-up: Accept/Undo passed

The session ending at 20:55:43 on September 11 is preserved in `C:\Dev\UploadLabsRecovery\godot-test7-combined-run1.log`.

- The Analyzer's same speed input was disconnected and generated a projected manager score of +4.
- At line 2901, `Accept connected` confirms the exact manager-to-Analyzer edge, and the interaction result is `ok=true code='accept_connected'` at line 2903.
- At lines 2925–2927, `Undo disconnected` and `ok=true code='undo_disconnected'` confirm removal of the same edge.
- The manual-choice observer ignored both AAC-owned deltas, avoiding duplicate learning (lines 2919 and 2941). Explicit accept and quick-undo preference events persisted; the later manual reconnection was learned separately and left the route preference at +6 (line 3095).
- The six graph revisions were 472, 472, 471, 472, 471, 472 edges, all with zero dangling/nonreciprocal/resource mismatch counts. The original Analyzer connection was restored manually at lines 3088–3091.
- All 14 manager records had matching raw demand mirrors and no raw reprojection failures. The only script error was the previously known base-game Ads error.

The log contains no observed GPU consumer disconnect/reconnect. Its GPU projections target only the existing GPU synchronizer inputs, all with zero incremental demand. Therefore the positive-demand GPU consumer check remains pending; the successful Analyzer Accept/Undo test does not need repeating.

## Follow-up: finite GPU consumer passed

The GPU session ending at 21:04:09 on September 11 is preserved in `C:\Dev\UploadLabsRecovery\godot-test7-gpu-consumer-run1.log` (SHA-256 `3fe0b4aeea9ac4868588b3d9a94fe4cad1f7b0afbf186d25ea7a818c38ca03a7`).

- At lines 2623–2626, `reinforcer6/Speed` (target `3e38ba56ea92`) was disconnected from `smart_gpu_manager0/Output` (source `ac39806e93cb`).
- At lines 2692–2693, Smart GPU Manager ranked first among 24 candidates at score 60 versus 58 for the next candidate, with an actual +4 manager adjustment and `manager_validation='runtime_validated_projected_headroom'`.
- Two projections (lines 2717 and 2829) reported positive target demand: approximately `7.09245e25` then `1.99878e26`. Their projected supply/demand ratios were 64.3210 and 59.8165, both using the count basis and `max(live demand, raw binding demand)` baseline. Both applied +4. Total ranking includes learned preference as well as the manager adjustment.
- Reconnection at lines 2851–2854 restored the exact original edge. Manager candidates returned from 11 to the 10 pre-existing candidates in samples 5–6.
- All 12 manager records had matching raw demand mirrors and zero raw reprojection failures. The graph remained clean across 472, 472, 471, 472 edges. No AAC script error occurred; the base-game Ads error remains.
- Post-startup observed FPS ranged from 63 to 120, averaging 114.42; this is telemetry, not a controlled benchmark.

The three planned test7 runtime gates are now complete: positive-demand Thread scoring, guarded Analyzer Accept/Undo, and positive-demand GPU scoring. This supersedes the pending GPU statements above. Together with the 58 automated checks, these establish the tested behavior for the exercised ASM Demand-mode configuration (Thread count/s, GPU count), not universal compatibility, optimal routing, or guaranteed performance. GPU Accept/Undo, other manager mode/basis combinations, and legacy standalone managers were not newly exercised in these sessions. The build remains test7; no publication or merge was performed.
