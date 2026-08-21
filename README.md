# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental adaptive player-controlled advisor  
**Current version:** 0.1.10  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector analyzes the live Upload Labs topology, ranks legal connection candidates, explains why a route may be preferable, learns bounded session preferences from confirmed player choices, and keeps the player in control.

> Player intent > optimizer score.

## What v0.1.10 does

v0.1.10 is the first adaptive-preference milestone layered on top of the runtime-verified v0.1.9 guarded connection controller.

- Keeps the v0.1.9 native advisor, exact module/connector locate flow, guarded `Accept connection`, `Find different way`, `No thank you`, and `Undo Last Accept` behavior.
- Adds a session-only semantic preference model; preferences are not persisted to disk yet.
- Successful Accept records a small positive preference (`+4`).
- `Find different way` records a small negative preference (`-1.5`) for the route the player moved away from.
- `No thank you` records a stronger negative preference (`-5`) while retaining the existing exact-pair session suppression behavior.
- A successful Undo within 30 seconds records `-8`; a later successful Undo records `-4`.
- Semantic preference scores are clamped to `-8 .. +8` advisory points.
- Semantic keys strip volatile runtime instance-number suffixes so recreated/duplicate module instances can share useful preference context.
- Preferences only reorder candidates that have already passed the legal-candidate generator. They do not change legality, `can_connect()`, guarded Accept checks, or mutation authority.
- The final advisory score remains capped at 90.

A representative semantic key from the runtime test was:

```text
heat_sink|4|heat|network|heat
```

This means feedback generalized across numbered Heat Sink and Network instances for the same connector/resource pattern, while other Heat Sink connector numbers remained separate contexts.

## v0.1.10 runtime verification

The accepted v0.1.10 test ran on Godot 4.6.1 with the existing 12-mod compatibility stack.

Verified behavior:

- The mod loaded and reached `v0.1.10 ready` without an Adaptive Auto Connector script error.
- One successful Network -> Heat Sink connector-4 Accept recorded `+4` preference.
- Undo 1.079 seconds later was classified as a quick undo and recorded `-8`, leaving that semantic route at net `-4`.
- A later `Find different way` on the same semantic route recorded `-1.5`, moving it from `-4` to `-5.5`.
- `No thank you` then recorded `-5` and correctly clamped the semantic preference to the `-8` floor.
- Before learning, Heat Sink connector 4 had seven tied top candidates at score 58 and the displayed recommendation was `network0/Heat`.
- On the later scoring sample after the preference reached `-8`, Heat Sink connector 4 had only three tied top candidates at score 58 and the displayed recommendation changed to `processor0/Heat`.
- The same connector-4 preference generalized from `heat_sink1` to `heat_sink0`, while Heat Sink connectors 1/2/3 retained their Network-family top choices.
- The graph remained clean at 236 windows, 875 containers, 441 edges, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges on captured graph revisions.
- Preference actions and the later scoring sample occurred alongside repeated approximately 165 FPS readings; no recurring adaptive-sample hitch was identified in the captured interaction segment.
- The only captured `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.

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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.10.zip` into `mods` without extracting it.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

## Next milestone

The next adaptive milestone is to observe manual player-created connection choices and decide how/when session preferences should become persistent without overgeneralizing one-off choices.

Before stronger optimizer claims are added, the project also still needs targeted validation of active Smart Thread/GPU Manager headroom behavior, broader production/required/demand semantics, and authoritative workspace/domain markers.
