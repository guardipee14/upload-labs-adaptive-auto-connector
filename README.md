# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental adaptive player-controlled advisor  
**Current version:** 0.1.13  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector analyzes the live Upload Labs topology, ranks legal connection candidates, explains why a route may be preferable, learns bounded semantic preferences from confirmed player choices, persists those preferences safely across sessions, and keeps the player in control.

> Player intent > optimizer score.

## What v0.1.13 does

v0.1.13 adds reversible repetitive-suggestion suppression on top of the runtime-verified v0.1.12 persistent preference store.

- Reuses persistence schema 1; no migration is required.
- A semantic route becomes soft-suppressed from the default suggestion slot only when its learned score is `<= -5` **and** it has at least two negative feedback events.
- Negative evidence includes `alternate`, `no_thanks`, and `undo`.
- One `No thank you` or one quick Undo by itself is not enough to create persistent soft suppression.
- Soft-suppressed candidates remain legal, remain in the scored candidate set, and remain reachable through `Find different way`.
- If the player explicitly navigates to a soft-suppressed route, AAC keeps displaying it because explicit player selection overrides the default suppression rule.
- If every legal candidate for a target is soft-suppressed, AAC falls back to the best legal candidate instead of hiding the target.
- Suppression does not alter `can_connect()`, candidate legality, guarded Accept, or topology mutation.
- No polling timer and no new topology-mutation path were added.

The first accepted runtime threshold example was:

```text
heat_sink|4|heat|network|heat
score: -5.0 -> -6.5
negative_events: 1 -> 2
```

After the second negative event, AAC marked the route soft-suppressed while still retaining it because the player had explicitly selected it.

## v0.1.13 runtime verification

The accepted v0.1.13 test ran on Godot 4.6.1 with the existing 12-mod compatibility stack across two focused sessions.

Verified behavior:

- Session 1 loaded existing schema-1 preferences unchanged and reached `v0.1.13 ready` without an AAC script error.
- The existing Network -> Heat Sink connector-4 semantic route began at `-5.0` and did not qualify for persistent soft suppression until a second negative event was recorded.
- One additional `Find different way` recorded `delta=-1.5`, moved the route from `-5.0` to `-6.5`, and produced `negative_events=2`.
- The same scoring sample logged the route with `retained_because_player_selected=true`, proving the player can still explicitly inspect a soft-suppressed legal route.
- Additional navigation continued to keep the explicitly selected soft route visible even after the learned score reached the `-8` floor.
- After a full game restart, Session 2 loaded the same schema-1 store at `event_index=15` before AAC reported ready.
- The first Session 2 recommendation sample reconstructed default suppression directly from persisted history without a schema migration or new player input.
- Three Heat Sink connector-4 targets logged `default_ineligible=true` and `legal_candidates_retained=true` while choosing a non-suppressed legal source.
- Captured graph revisions remained at 454 edges with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.
- Steady-state FPS around suppression/scoring remained in the same general range as prior builds; no recurring suppression hitch was identified.
- The only captured `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.

## Persistent preference learning

Schema-1 preferences remain stored at:

```text
user://AdaptiveAutoConnector/preferences.json
```

with backup protection at:

```text
user://AdaptiveAutoConnector/preferences.backup.json
```

Current learning signals remain:

- AAC Accept: `+4`
- Strict manual player-created connection: `+6`
- Find different way: `-1.5`
- No thank you: `-5`
- Quick Undo: `-8`
- Late/unknown Undo: `-4`

Preference influence remains bounded to `-8 .. +8`. Persisted values are validated and re-clamped on load, entries older than 180 days without reinforcement are pruned, and a newer unknown schema puts persistence into read-only mode instead of being overwritten.

Quick-Undo timing itself is never restored across sessions.

## Manual-choice observation

AAC passively observes strict simple manual player-created connection additions through the existing topology delta stream.

A manual choice is learned only when the change is unambiguous: one new edge, no unsuppressed removal, no container churn, reciprocal live endpoints, valid connector directions, non-black connectors, and exact non-empty resource match.

AAC-owned Accept and Undo topology changes are tagged and ignored by the manual observer so they are not double-counted as manual player choices. Ambiguous multi-edge/container churn is skipped rather than guessed.

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
- bounded persistent player-preference adjustment (`-8 .. +8`);
- reversible default-slot suppression from repeated negative preference history;
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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.13.zip` into `mods` without extracting it.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

## Next milestone

The next adaptive milestone is a user-facing preference/settings and diagnostics surface so the player can inspect learned semantic preferences, understand why a route is quieted, and reset learned data without touching the persistence file manually.

Before stronger optimizer claims are added, the project also still needs targeted validation of active Smart Thread/GPU Manager headroom behavior, broader production/required/demand semantics, and authoritative workspace/domain markers.
