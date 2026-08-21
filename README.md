# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.4  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is a player-controlled connection advisor in development for Upload Labs. The long-term design is to analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player intent must take priority over optimizer score.

## What v0.1.4 does

v0.1.4 remains completely read-only. It keeps the runtime-verified topology observer, normalized graph, and resource model, then adds a candidate generator that:

- starts only from high-confidence unserved required inputs;
- requires exact non-empty resource matches;
- requires source/output and target/input connector roles;
- rejects black connectors, self-links, and already-present links;
- resolves live ResourceContainers through `Globals.desktop.get_resource(...)`;
- requires the game's own `can_connect(...)` check to accept the pair;
- stores only plain candidate records;
- reuses the existing approximately 10-second resource sample path and adds no second timer;
- does **not** rank, recommend, or create any connection yet.

## Runtime verification

The v0.1.4 real-save test passed with the same 12-mod compatibility stack. The graph reported 235 windows, 870 containers, 431 edges, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.

Candidate generation consistently found:

- 13 unserved required targets;
- 12 targets with at least one verified candidate;
- 100 `verified_can_connect` candidate pairs;
- 202 structurally rejected same-resource pairs;
- 0 live-compatibility rejections.

The Quantum Processor's unserved `qubit` input correctly remained at 0 candidates because no compatible `qubit` producer was present.

The live test also showed that `can_connect()` is permissive for structurally valid same-resource pairs in this save. For example, trainer inputs had 18-19 legal sources and tested heat-sink inputs had 8. Therefore v0.1.4 establishes **legality/compatibility**, not efficiency. Candidate ordering is not a recommendation.

Later resource/candidate passes ran alongside roughly 123-160 FPS in the captured log, without evidence of the old recurring observer hitch. The only `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` error outside Adaptive Auto Connector.

## Verified compatibility IDs

- Smart Thread Manager by kuuk — `kuuk-SmartThreadManager`
- Smart GPU Manager by kuuk — `kuuk-SmartGPUManager`
- SmartConnections by helios — `Helios-SmartConnections`
- Upload Labs+ by chingcm — `chingcm-UploadLabsPlus`
- Upload Labs+ ModUtils — `chingcm-ModUtils`
- Taj's Mods - Core — `TajemnikTV-Core`

No compatibility mod is required for the base mod to load.

## Manual installation

The verified manual-install method is the local `mods` folder with the ZIP left intact.

1. Close Upload Labs.
2. Find the game's installation folder, typically `SteamLibrary\steamapps\common\Upload Labs`.
3. Create `Upload Labs\mods` if needed.
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.4.zip` into `mods` **without extracting it**.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

Expected candidate logging includes:

```text
[guardipee14-AdaptiveAutoConnector][Candidates] Sample index=... unserved_targets=... targets_with_candidates=... verified_candidates=...
[guardipee14-AdaptiveAutoConnector][Candidates]   Target ... candidates=...
[guardipee14-AdaptiveAutoConnector][Candidates]     Candidate ... compatibility='verified_can_connect'
```

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Planned next steps

v0.1.4 is runtime-verified. The next milestone is read-only **candidate scoring and explanation**: use capacity/load, existing fan-out, resource demand, topology context, and player-preservation rules to rank legal candidates without changing the network. Automatic connection changes remain a later milestone.
