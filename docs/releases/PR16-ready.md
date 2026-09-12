# Prepared PR #16 update

Local draft only. Apply after the recovered source and tests are pushed to the PR branch.

Suggested title: `fix(advisor): validate bounded manager scoring and zero-required speed candidates`

## Summary

Recover the tested v0.1.15 manager-projection implementation and fix zero-required CPU/GPU speed inputs being filtered out before candidate scoring. Add regression tests and targeted runtime evidence for v0.1.15-test7.

- Preserve live candidate legality and the existing guarded Accept/Undo controller.
- Validate raw bound demand against the independent mirror; do not require raw demand to equal live smoothed demand.
- Project from `max(live demand, raw bound demand)` plus the target's demand in the detected count/count-s basis.
- Apply a bounded -4 through +4 manager adjustment only when projection validation succeeds; retain zero fallback, independent bounded preferences and the advisory-score cap.
- Detect ASM explicitly without falsely reporting its replaced standalone manager mods as missing.
- Admit only numeric-zero `clock_speed` / `gpu_speed` requirements in addition to ordinary positive requirements; preserve the actual zero value.
- Use existing sample signals; add no timer, automatic connection behavior or manager distribution ownership.

## Validation completed

- 58 headless checks passed in Godot 4.6.1, including +/-4 scoring, invalid-provider/mirror zero fallback, legality filters and reconnect disappearance.
- Positive-demand Thread candidate ranked with an actual +4 contribution.
- Analyzer Accept and Undo operated on the exact expected edge; manual learning excluded AAC-owned deltas.
- Positive-demand GPU Reinforcer candidate ranked with an actual +4 contribution.
- Raw mirrors agreed, graph integrity errors stayed zero, and original topology was restored in all three game sessions. No AAC script error appeared.

Evidence: `tests/RUNTIME_TEST7.md`; exact artifact record: `tests/test7-package.json`; release handoff: `docs/releases/0.1.15-test7.md`.

## Scope and release caveat

Game validation used the original ASM test20 archive, not the different ZIP currently attached to GitHub's same-named release. Coverage is ASM Demand mode, Thread count/s and GPU count. Other modes/bases, legacy managers and GPU Accept/Undo remain outside the new runtime evidence. Scores are advisory, not throughput guarantees. The known base-game Ads error remains.

The old PR's diagnostic-only zero-score acceptance gates are superseded by this bounded-scoring evidence. Public release still requires source/artifact reconciliation for ASM; passing these tests does not authorize replacing an existing release or announcing universal compatibility.
