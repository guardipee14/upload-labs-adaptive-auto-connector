# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.2  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is planned as a player-controlled connection advisor for Upload Labs. It will analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player decisions and manual connection choices will influence future suggestions instead of being overridden.

## What v0.1.2 does

v0.1.2 is still read-only. It keeps the runtime-verified v0.1.1 observer and adds a normalized in-memory topology graph that:

- represents each observed Upload Labs window as a plain-data window record;
- represents each resource container by its runtime ID, window, resource, connector role, and current links;
- represents each observed output connection as a directed `from -> to` edge;
- classifies connector roles as `source`, `sink`, `relay`, or `passive`;
- builds indexes by raw runtime resource ID and current domain hint;
- checks edges for dangling targets, non-reciprocal links, duplicate links, and resource mismatches;
- updates from the observer's existing five-second lightweight state instead of adding another polling loop;
- exposes a deep-copied graph snapshot for future bottleneck and recommendation analyzers;
- makes **no connection, topology, save, coding, hacking, or factory changes**.

The normalized graph intentionally stores data rather than Godot node references. Runtime node references are used only transiently when a brand-new container needs metadata, then discarded from the graph model.

## Runtime verification

v0.1.2 passed a real-save runtime test with the same 12-mod compatibility stack used for v0.1.1. The observer and graph matched exactly at startup with 233 windows, 861 resource containers, and 423 live connections/edges. The graph indexed 72 distinct runtime resource IDs and classified 303 sources, 543 sinks, 0 relays, and 15 passive containers with 0 unidentified containers.

Across eight graph revisions, observer connection counts and graph edge counts remained synchronized while live rewires moved between 421, 422, and 423 edges. Edge validation remained clean throughout: 0 dangling edges, 0 non-reciprocal edges, and 0 resource mismatches. The v0.1.1 performance fix also remained effective; normal gameplay after startup stayed mostly around 150-165 FPS in the captured test log without the earlier periodic frame hitch.

Current discovery-only domain hints on the tested save are 213 system/unknown windows, 11 Coding candidates, 8 Hacking candidates, and 1 Factory candidate. These are not yet authoritative game-domain classifications.

## Planned core support

- Main Upload Labs system/network connections
- Hacking
- Coding
- Factory
- CPU, GPU, storage, network, and other vanilla resources
- Explainable suggestions with Accept / Find a different way / No thank you
- Dynamic preference learning from accepted, rejected, alternate, and manual choices
- Undo/snapshot protection before any future automatic change

## Verified runtime discoveries

### Compatibility IDs
- Smart Thread Manager by kuuk — `kuuk-SmartThreadManager`
- Smart GPU Manager by kuuk — `kuuk-SmartGPUManager`
- SmartConnections by helios — `Helios-SmartConnections`
- Upload Labs+ by chingcm — `chingcm-UploadLabsPlus`
- Upload Labs+ ModUtils — `chingcm-ModUtils`
- Taj's Mods - Core (Library) — `TajemnikTV-Core`

### Resource examples
- Hacking: `hack_power`, `payload_damage`, `infection_damage`, `hack_experience`
- Coding: `code_bugfix`, `code_optimization`, `code_speed`, `contribution`
- Smart Thread Manager: smart `clock_speed` output with runtime `demand`
- Smart GPU Manager: smart `gpu_speed` output with runtime `demand`
- Factory: `router_assembler` observed using `pcb` input, `router` output, and `work_speed`

No compatibility mod is required for the base mod to load.

## Manual installation

The verified manual-install method is the local `mods` folder with the release ZIP left intact.

1. Close Upload Labs.
2. Find the game's installation folder. A typical Steam library path is:

   `SteamLibrary\steamapps\common\Upload Labs`

3. Create this folder if it does not already exist:

   `SteamLibrary\steamapps\common\Upload Labs\mods`

4. Copy the release ZIP into that folder **without extracting it**:

   `guardipee14-AdaptiveAutoConnector-v0.1.2.zip`

5. The layout is:

```text
Upload Labs
└─ mods
   └─ guardipee14-AdaptiveAutoConnector-v0.1.2.zip
```

6. Remove older Auto Connector ZIPs from the same `mods` folder so only one version with the same Mod Loader ID is present.
7. Launch Upload Labs and load a save.
8. Check the game/mod-loader log for lines beginning with:

   `[guardipee14-AdaptiveAutoConnector]`

The observer should report:

```text
[guardipee14-AdaptiveAutoConnector][Topology] Observer active; lightweight read-only scan interval 5.0s.
```

The graph reports summaries such as:

```text
[guardipee14-AdaptiveAutoConnector][Graph] Graph revision=1 reason=initial windows=... containers=... edges=... resources=...
[guardipee14-AdaptiveAutoConnector][Graph] Roles source=... sink=... relay=... passive=... unidentified=...
[guardipee14-AdaptiveAutoConnector][Graph] Domain hints ...
```

After a manual rewire, later graph revisions track the observer's connection count.

### Development note

The repository keeps source under `mods-unpacked/guardipee14-AdaptiveAutoConnector` because that is the readable development/source layout. On the tested exported game build, direct loose loading from `res://mods-unpacked/` currently fails with a Mod Loader `Invalid parameter` path error, while the local `mods` ZIP method works correctly.

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Steam Workshop

Workshop packaging is planned after the manual-install build is stable. The same mod source will be used for the Workshop package so manual and Workshop installs do not become separate codebases.

## Development status

v0.1.2 is the runtime-verified normalized topology-graph milestone. The next work is to classify raw runtime resources and authoritative domains well enough to begin read-only bottleneck analysis and compatible candidate generation without mutating the player's layout.
