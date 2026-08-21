# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental adaptive player-controlled advisor  
**Current version:** 0.1.12  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector analyzes the live Upload Labs topology, ranks legal connection candidates, explains why a route may be preferable, learns bounded semantic preferences from confirmed player choices, persists those preferences safely across sessions, and keeps the player in control.

> Player intent > optimizer score.

## What v0.1.12 does

v0.1.12 adds versioned, schema-safe persistence on top of the runtime-verified v0.1.11 manual/adaptive learning stack.

- Stores semantic preferences at `user://AdaptiveAutoConnector/preferences.json` using persistence schema version 1.
- Writes `preferences.backup.json` before replacing an existing primary preference file.
- Restores learned semantic scores before candidate scoring begins on a new game session.
- Re-clamps every loaded score to the existing `-8 .. +8` advisory range.
- Persists event counts, last-event metadata, event index, and a wall-clock update timestamp.
- Keeps quick-Undo timing session-local: `_last_accept_key` and the 30-second Undo clock are cleared on hydration and are never restored from disk.
- Prunes entries after 180 days without reinforcement instead of treating old behavior as permanent intent.
- Refuses malformed or unsupported primary data safely; a newer unknown schema switches persistence to read-only so an older AAC version cannot overwrite future-format data.
- Can recover from a valid schema-1 backup when the primary is invalid.
- Exposes `reset_persistent_preferences()` for a later settings/diagnostics UI.
- Adds no polling timer and no new topology-mutation path.
- The guarded connection controller, topology observer, manual-choice ownership suppression, candidate legality, and learning weights remain unchanged.

The accepted runtime persistence example used:

```text
heat_sink|4|heat|network|heat = -5
```

That preference survived a full Upload Labs restart and affected the first candidate-scoring sample before any new player interaction.

## v0.1.12 runtime verification

The accepted v0.1.12 test ran on Godot 4.6.1 with the existing 12-mod compatibility stack across three focused sessions.

Verified behavior:

- Session 1 loaded v0.1.12 with no existing preference file and reached ready without an AAC script error.
- One `No thank you` recorded `heat_sink|4|heat|network|heat` with `delta=-5`, `before=0`, `after=-5`, `persisted=true`.
- The first save wrote schema 1 with one entry and `event_index=1`.
- Before that preference, Heat Sink connector 4 had seven tied top candidates at advisory score 58 led by Network-family sources.
- After the `-5` preference, the same connector dropped to three tied top candidates at 58, all Processor-family sources.
- After a full game restart, Session 2 loaded `schema=1`, `source='primary'`, `entries=1`, `pruned_stale=0`, `sanitized=0`, and `event_index=1` before AAC reported ready.
- The very first Session 2 scoring sample already ranked Processor-family sources for Heat Sink connector 4, while connectors 1, 2, and 3 continued ranking Network-family sources normally.
- Session 3 again loaded the existing primary at `event_index=1`; one `Find different way` recorded a new semantic Processor-route preference with `delta=-1.5` and successfully saved `entries=2`, `event_index=2`.
- Because the persistence implementation refuses to replace an existing primary if the backup write fails, the successful Session 3 save also runtime-proved the existing-primary backup-write path.
- Captured graph revisions remained at 454 edges with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges during the persistence tests.
- Captured steady-state FPS remained generally in the previously observed range after transient topology activity; no recurring persistence polling or write hitch was identified.
- The only captured `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.
- Dynamic Trainer recreation continued to be skipped as ambiguous manual-choice churn rather than learned.

## What v0.1.11 added

v0.1.11 added passive observation of strict simple manual player-created connections on top of the runtime-verified v0.1.10 adaptive preference model.

- Reuses the existing topology observer delta stream; no second polling timer is introduced.
- Learns only from strict simple additions: one new unsuppressed edge, no unsuppressed removal, no container churn, reciprocal live endpoints, valid connector directions, non-black connectors, and exact non-empty resource match.
- Records a qualified manual choice as `+6` advisory preference points, bounded by the existing `-8 .. +8` clamp.
- Keeps semantic keys instance-independent so recreated numbered/runtime IDs do not become preference identity.
- AAC-owned `Accept connection` additions are tagged by the existing connection controller and ignored by the manual observer, preventing duplicate `+6` learning.
- AAC-owned Undo removals are also ignored by the manual observer while retaining the normal quick/late Undo preference behavior.
- Accept -> Undo that completes before the next observer sample collapses the pending ownership marker so a later manual redraw can still be observed.
- Ambiguous multi-edge changes and container churn are skipped rather than guessed.
- The guarded connection controller remains unchanged from v0.1.10.

A representative runtime-learned manual semantic key was:

```text
optimize_code|input|code_driver|code_driver|code
```

The corresponding manual edge was learned with `confidence='strict_simple_addition'` and `delta=+6` while the graph stayed structurally clean.

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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.12.zip` into `mods` without extracting it.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

## Next milestone

The next adaptive milestone is learned repetitive-suggestion suppression: use persistent semantic context to reduce suggestions the player repeatedly declines without turning one-off feedback into a permanent global rejection.

Before stronger optimizer claims are added, the project also still needs targeted validation of active Smart Thread/GPU Manager headroom behavior, broader production/required/demand semantics, and authoritative workspace/domain markers.
