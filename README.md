# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental adaptive player-controlled advisor  
**Current version:** 0.1.11  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector analyzes the live Upload Labs topology, ranks legal connection candidates, explains why a route may be preferable, learns bounded session preferences from confirmed player choices, and keeps the player in control.

> Player intent > optimizer score.

## What v0.1.11 does

v0.1.11 adds passive observation of strict simple manual player-created connections on top of the runtime-verified v0.1.10 adaptive preference model.

- Reuses the existing topology observer delta stream; no second polling timer is introduced.
- Learns only from strict simple additions: one new unsuppressed edge, no unsuppressed removal, no container churn, reciprocal live endpoints, valid connector directions, non-black connectors, and exact non-empty resource match.
- Records a qualified manual choice as `+6` advisory preference points, bounded by the existing `-8 .. +8` session clamp.
- Keeps semantic keys instance-independent so recreated numbered/runtime IDs do not become preference identity.
- AAC-owned `Accept connection` additions are tagged by the existing connection controller and ignored by the manual observer, preventing duplicate `+6` learning.
- AAC-owned Undo removals are also ignored by the manual observer while retaining the normal quick/late Undo preference behavior.
- Accept -> Undo that completes before the next observer sample collapses the pending ownership marker so a later manual redraw can still be observed.
- Ambiguous multi-edge changes and container churn are skipped rather than guessed.
- Preference state remains session-only; no disk persistence yet.
- The guarded connection controller remains unchanged from v0.1.10.

A representative runtime-learned manual semantic key was:

```text
optimize_code|input|code_driver|code_driver|code
```

The corresponding manual edge was learned with `confidence='strict_simple_addition'` and `delta=+6` while the graph stayed structurally clean.

## v0.1.11 runtime verification

The accepted v0.1.11 test ran on Godot 4.6.1 with the existing 12-mod compatibility stack.

Verified behavior across the two focused runtime runs:

- The mod loaded and reached `v0.1.11 ready` without an Adaptive Auto Connector script error.
- The manual observer established a baseline of 888 containers and 453 edges.
- Dynamic Trainer recreation produced 18 additions, 18 removals, 18 added containers, and 18 removed containers in one sample; the manual observer correctly skipped it as `ambiguous_delta` instead of learning from churn.
- One manually drawn `code_driver0/Code -> optimize_code0/Input` connection produced exactly one `manual_choice` event with `delta=+6`, `before=0`, `after=6`, and `confidence='strict_simple_addition'`.
- The learned semantic key was `optimize_code|input|code_driver|code_driver|code`, containing no transient runtime IDs or numbered instance suffixes.
- That manual addition moved the graph from 453 to 454 edges with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.
- In the companion ownership test, one AAC Accept was marked as an AAC-owned addition and ignored by the manual observer while still recording the normal `accept +4` preference.
- The following AAC Undo was marked as an AAC-owned removal and ignored by the manual observer while still recording the normal quick-Undo `-8` preference.
- That AAC Accept -> Undo cycle moved 453 -> 454 -> 453 edges with graph integrity remaining clean.
- Captured steady-state readings around the manual event returned to roughly 154-161 FPS after transient interaction/topology activity; no new recurring manual-observer polling hitch was identified.
- The only captured `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.
- The known SmartConnections `connection_droppped` signal arity error remained external to AAC.

## Guarded Accept

Every displayed route gets a live guard snapshot. When `Accept connection` is pressed, the controller revalidates the exact live source and target before emitting one create signal. Accept refuses if the recommendation is stale or if guarded topology changed.

Current checks include:

- exact runtime source and target still exist;
- expected output/input connector directions still exist;
- connector state/color has not changed or become blocked;
- source and target resources still match the recommendation;
- target is still unserved;
- the source's complete output-route set is unchanged from the displayed guard;
- the edge does not already exist;
- the game still reports the pair as connectable through `can_connect()`.

Visual locate may use a strict same-module fallback for recreated runtime container IDs, but mutation does not: Accept refuses stale endpoint IDs and waits for a fresh recommendation.

## Scoring semantics

Scoring remains conservative relative advisory ordering, not a throughput promise or percentage improvement. Current signals include:

- verified legal candidate;
- unserved target / route preservation;
- positive observed production;
- capped provisional `production / required` hint;
- nonlinear shared-source penalty;
- explicit top-score tie/ambiguity handling;
- narrowly scoped Smart Manager headroom hook for known manager/resource pairs when live metrics are readable;
- bounded session player-preference adjustment (`-8 .. +8`);
- final advisory-score cap of 90.

Broader `production`, `required`, and `demand` semantics remain under validation.

## Verified compatibility IDs

- Smart Thread Manager — `kuuk-SmartThreadManager`
- Smart GPU Manager — `kuuk-SmartGPUManager`
- SmartConnections — `Helios-SmartConnections`
- Upload Labs+ — `chingcm-UploadLabsPlus`
- Upload Labs+ ModUtils — `chingcm-ModUtils`
- Taj's Mods - Core — `TajemnikTV-Core`

These are optional compatibility targets; none is a hard dependency for the base mod.

## Manual installation

The verified manual-install method is the local `mods` folder with the ZIP left intact.

1. Close Upload Labs.
2. Find the game folder, typically `SteamLibrary\steamapps\common\Upload Labs`.
3. Create `Upload Labs\mods` if needed.
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.11.zip` into `mods` without extracting it.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

## Next milestone

The next adaptive milestone is versioned/schema-safe persistence so useful learned preferences can survive game sessions without turning a one-off choice into an irreversible global rule. Repetitive-suggestion suppression should then use that learned context conservatively.

Before stronger optimizer claims are added, the project also still needs targeted validation of active Smart Thread/GPU Manager headroom behavior, broader production/required/demand semantics, and authoritative workspace/domain markers.
