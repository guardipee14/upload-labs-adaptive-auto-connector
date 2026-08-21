# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental player-controlled advisor  
**Current version:** 0.1.9  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector analyzes the live Upload Labs topology, ranks legal connection candidates, explains why a route may be preferable, and keeps the player in control.

> Player intent > optimizer score.

## What v0.1.9 does

v0.1.9 is the first player-controlled topology-mutation milestone.

- Native advisor button in Upload Labs' right-side extras toolbar.
- Native-themed advisor window with recommendation details, scoring, confidence, tie/unique status, and explanations.
- `Locate Target` / `Locate Source` center and select the exact module.
- Exact connector highlighting: target inputs and source outputs are visually marked on the real connector control.
- `Find different way` cycles another ranked legal source for the same target without changing topology.
- `No thank you` suppresses only that semantic source-target context for the current play session.
- `Accept connection` is the only advisor action allowed to mutate topology.
- `Undo Last Accept` removes only the most recent connection created through Adaptive Auto Connector when that exact edge still exists.

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

## v0.1.9 runtime verification

The accepted v0.1.9 test series ran on Godot 4.6.1 with the existing 12-mod compatibility stack.

Verified behavior:

- `Find different way` changed only the displayed source and did not mutate topology.
- `No thank you` suppressed individual recommendation contexts for the current session and moved through remaining alternatives.
- A guarded Accept created exactly one approved edge; the normalized graph increased by exactly one edge and remained consistent.
- `Undo Last Accept` removed exactly that accepted edge; the graph returned to its prior edge count.
- A changed-topology recommendation was runtime-rejected with `accept_source_routes_changed`; no edge was created by the refused Accept.
- Graph validation remained at 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges during the tested create/undo/refusal transitions.
- The fixed interaction layout kept Accept / Find different way / No thank you / Undo visible inside the game viewport.
- The only captured `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.

## Scoring semantics

Scoring remains conservative relative advisory ordering, not a throughput promise or percentage improvement. Current signals include:

- verified legal candidate;
- unserved target / route preservation;
- positive observed production;
- capped provisional `production / required` hint;
- nonlinear shared-source penalty;
- explicit top-score tie/ambiguity handling;
- narrowly scoped Smart Manager headroom hook for known manager/resource pairs when live metrics are readable;
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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.9.zip` into `mods` without extracting it.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

## Next milestone

The next major milestone is adaptive preference learning: learn from accepted routes, alternate requests, and rejections while continuing to preserve player intent and keeping automatic topology changes opt-in.

Before stronger optimizer claims are added, the project also still needs targeted validation of active Smart Thread/GPU Manager headroom behavior and broader production/required/demand semantics.
