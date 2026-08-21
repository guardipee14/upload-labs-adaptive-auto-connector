# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.1  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is planned as a player-controlled connection advisor for Upload Labs. It will analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player decisions and manual connection choices will influence future suggestions instead of being overridden.

## What v0.1.1 does

v0.1.1 is still read-only. It:

- loads as a local ZIP mod;
- reports active Mod Loader mod IDs to the game log;
- detects verified optional compatibility mods by exact runtime ID;
- detects Taj's Core runtime metadata when available;
- waits for the live Upload Labs desktop and `Windows` container;
- records a one-time detailed discovery snapshot of windows and resource containers;
- monitors topology with a lightweight five-second fingerprint based on window/container IDs and current links;
- logs compact deltas only when windows, containers, or connections actually change;
- makes **no connection, topology, save, coding, hacking, or factory changes**.

v0.1.1 passed two real-save runtime tests with the 12-mod compatibility stack. The first implementation used a full detailed rescan every two seconds and caused visible periodic frame drops. The optimized implementation instead uses a lightweight five-second fingerprint; the repeating frame drop was eliminated while live rewires were still detected correctly. The optimized test observed 233 windows, 861 resource containers, and 419 existing connections, then tracked later rewires as the count advanced to 420, 421, and 423.

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

   `guardipee14-AdaptiveAutoConnector-v0.1.1.zip`

5. The verified layout is:

```text
Upload Labs
└─ mods
   └─ guardipee14-AdaptiveAutoConnector-v0.1.1.zip
```

6. Remove older Auto Connector ZIPs from the same `mods` folder so only one version with the same Mod Loader ID is present.
7. Launch Upload Labs and load a save.
8. Check the game/mod-loader log for lines beginning with:

   `[guardipee14-AdaptiveAutoConnector]`

A successful startup begins the topology observer and later reports:

```text
[guardipee14-AdaptiveAutoConnector][Topology] Observer active; lightweight read-only scan interval 5.0s.
```

Topology changes are reported as compact `Delta` / `Rewired` / `Added` / `Removed` lines instead of repeating the full graph.

### Development note

The repository keeps source under `mods-unpacked/guardipee14-AdaptiveAutoConnector` because that is the readable development/source layout. On the tested exported game build, direct loose loading from `res://mods-unpacked/` currently fails with a Mod Loader `Invalid parameter` path error, while the local `mods` ZIP method works correctly.

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Steam Workshop

Workshop packaging is planned after the manual-install build is stable. The same mod source will be used for the Workshop package so manual and Workshop installs do not become separate codebases.

## Development status

v0.1.1 is the runtime-verified read-only topology-observer milestone. The next milestone is a normalized read-only topology graph that can classify resource roles and support bottleneck/candidate analysis without mutating the player's layout.
