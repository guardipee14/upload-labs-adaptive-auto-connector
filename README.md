# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.3  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is planned as a player-controlled connection advisor for Upload Labs. It will analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player decisions and manual connection choices will influence future suggestions instead of being overridden.

## What v0.1.3 does

v0.1.3 remains completely read-only. It keeps the runtime-verified topology observer and normalized graph from v0.1.2, then adds a resource model that:

- classifies observed runtime resources into broad families: compute, network, media, coding, hacking, factory, AI, data type, economy, and progression;
- samples `resource`, `production`, `required`, and optional `demand` values without calling `get_property_list()` in the periodic hot path;
- reuses the existing five-second observer timer and samples numeric resource state every second scan (approximately every 10 seconds), so no second polling timer is added;
- identifies structural **unserved required inputs** when a real resource input has `required > 0` and no current source connection;
- identifies **idle active producers** when a producer currently reports positive production but has no consumers;
- counts connected `production < required` observations separately as **experimental** because those runtime semantics are not yet proven safe enough to call a bottleneck;
- prints one compact sample summary and only reprints detailed structural records when the structural set changes;
- makes **no connection, topology, save, coding, hacking, or factory changes**.

The resource model stores plain data. Runtime node references are only used transiently by the observer to read a few numeric fields.

## Runtime verification

The corrected v0.1.3 test passed on the same 12-mod compatibility stack. At startup, the graph remained aligned with the previous baseline at 233 windows, 861 resource containers, 423 live edges, and 72 distinct resource IDs, with zero dangling, non-reciprocal, or resource-mismatch edges.

The resource catalog classified all 72 observed resource IDs with zero unknowns. Runtime family counts were AI 9, Coding 6, Compute 4, Data Type 13, Economy 3, Factory 5, Hacking 10, Media 18, Network 2, and Progression 2.

The resource sampler completed indices 1 through 23. The high-confidence **unserved required input** count remained stable at 13 through the entire run, while live topology changes increased the observed model from 861 to 870 containers and the graph advanced through 13 revisions up to 431 edges without losing consistency.

The initial sample showed many connected `production < required` cases while the save was still settling, and later samples reported far fewer. This reinforces the decision to keep those connected-gap values experimental instead of treating them as confirmed bottlenecks.

Late-run resource samples occurred alongside roughly 151-165 FPS in the captured log, with no evidence of the earlier periodic sampler-induced frame hitch. The only `SCRIPT ERROR` in the corrected run was the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.

## Resource-family examples

- Compute: `clock_speed`, `cpu_core`, `gpu`, `gpu_speed`
- Network: `download_speed`, `upload_speed`
- Media/file flow: `text`, `image`, `sound`, `video`, `program`, `game`, plus `torrent_*` and `zip_*`
- Coding: `code_application`, `code_bugfix`, `code_driver`, `code_optimization`, `code_speed`, `contribution`
- Hacking: `hack_power`, `hack_experience`, `payload_damage`, `infection_damage`, `dos_damage`, `vulnerability`, and related data/status resources
- Factory: `pcb`, `router`, `work_speed`, `heat`, `overclock`
- AI/quantum: `neuron_*`, `quantum_solver`, `quantum_solver_gpu`, `qubit`
- Coding data types: primitive/array/hashmap/vector resource IDs observed in the live save
- Economy/progression: `money`, `ethereum`, `litecoin`, `research`, `research_power`

These are classification families for analysis, not assumptions that all members share identical production semantics.

## Verified compatibility IDs

- Smart Thread Manager by kuuk — `kuuk-SmartThreadManager`
- Smart GPU Manager by kuuk — `kuuk-SmartGPUManager`
- SmartConnections by helios — `Helios-SmartConnections`
- Upload Labs+ by chingcm — `chingcm-UploadLabsPlus`
- Upload Labs+ ModUtils — `chingcm-ModUtils`
- Taj's Mods - Core (Library) — `TajemnikTV-Core`

No compatibility mod is required for the base mod to load.

## Manual installation

The verified manual-install method is the local `mods` folder with the ZIP left intact.

1. Close Upload Labs.
2. Find the game's installation folder, typically `SteamLibrary\steamapps\common\Upload Labs`.
3. Create `Upload Labs\mods` if needed.
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.3.zip` into `mods` **without extracting it**.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

Expected resource-model logging includes:

```text
[guardipee14-AdaptiveAutoConnector][Resources] Catalog containers=... distinct_resources=... unknown_resources=... families ...
[guardipee14-AdaptiveAutoConnector][Resources] Sample reason=initial index=1 containers=... numeric=... unserved_required_inputs=... idle_active_producers=... experimental_connected_gaps=...
```

The normal topology observer still uses a five-second lightweight scan, while resource numeric sampling occurs approximately every 10 seconds.

### Development note

The repository keeps source under `mods-unpacked/guardipee14-AdaptiveAutoConnector` because that is the readable development/source layout. On the tested exported game build, direct loose loading from `res://mods-unpacked/` currently fails with a Mod Loader path error, while the local `mods` ZIP method works correctly.

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Planned next steps

v0.1.3 is runtime-verified. The next work is to validate enough of the live `production`, `required`, and `demand` semantics to distinguish capacity from demand safely, then generate **read-only compatible connection candidates** from the normalized graph and structural observations. Automatic connection changes remain a later milestone.
