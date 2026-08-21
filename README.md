# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.1  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is planned as a player-controlled connection advisor for Upload Labs. It will analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player decisions and manual connection choices will influence future suggestions instead of being overridden.

## What v0.1.1 does

v0.1.1 remains deliberately read-only. It:

- loads as a local ZIP mod;
- reports active Mod Loader mod IDs;
- detects verified optional compatibility mods by exact runtime ID;
- detects Taj's Core runtime metadata when available;
- waits safely for `Globals.desktop` and its `Windows` node;
- enumerates live `WindowBase` instances;
- enumerates each window's resource containers;
- records container IDs, input IDs, output IDs, connector presence, connector color, scene path, script path, and selected discovery properties;
- computes a stable topology signature and rescans every 2 seconds;
- logs a new snapshot only when windows, containers, connectors, or links change;
- adds **discovery-only** domain hints for likely System/Hacking/Coding/Factory windows so runtime data can be verified before those classifications affect recommendations;
- makes **no connection, topology, save, coding, hacking, or factory changes**.

The topology observer intentionally does not emit connection-creation/deletion signals and does not re-register game resources.

## Planned core support

- Main Upload Labs system/network connections
- Hacking
- Coding
- Factory
- CPU, GPU, storage, network, and other vanilla resources
- Explainable suggestions with Accept / Find a different way / No thank you
- Dynamic preference learning from accepted, rejected, alternate, and manual choices
- Undo/snapshot protection before any future automatic change

## Verified optional compatibility IDs

- Smart Thread Manager by kuuk — `kuuk-SmartThreadManager`
- Smart GPU Manager by kuuk — `kuuk-SmartGPUManager`
- SmartConnections by helios — `Helios-SmartConnections`
- Upload Labs+ by chingcm — `chingcm-UploadLabsPlus`
- Upload Labs+ ModUtils — `chingcm-ModUtils`
- Taj's Mods - Core (Library) — `TajemnikTV-Core`

No compatibility mod is required for the base mod to load.

## Manual installation

The verified manual-install method is the local `mods` folder with the release ZIP left intact.

1. Close Upload Labs.
2. Find the game's installation folder. A typical Steam library path is:

   `SteamLibrary\steamapps\common\Upload Labs`

3. Create this folder if it does not already exist:

   `SteamLibrary\steamapps\common\Upload Labs\mods`

4. Remove the previous Auto Connector ZIP if present, then copy the new release ZIP into that folder **without extracting it**:

   `guardipee14-AdaptiveAutoConnector-v0.1.1.zip`

5. The verified layout is:

```text
Upload Labs
└─ mods
   └─ guardipee14-AdaptiveAutoConnector-v0.1.1.zip
```

6. Launch Upload Labs and load a save with a useful mixture of System, Hacking, Coding, and Factory windows if possible.
7. Create or remove one normal connection during the test so the observer can prove its change detection.
8. Close Upload Labs normally and inspect `godot.log` for lines beginning with:

   `[guardipee14-AdaptiveAutoConnector]`

A healthy v0.1.1 startup should include lines similar to:

```text
[guardipee14-AdaptiveAutoConnector] v0.1.1 loading...
[guardipee14-AdaptiveAutoConnector][Topology] Waiting for desktop topology...
[guardipee14-AdaptiveAutoConnector][Topology] Snapshot reason=initial ...
[guardipee14-AdaptiveAutoConnector][Topology] Observer active; read-only scan interval 2.0s.
```

After a connection or window topology change, it should emit:

```text
[guardipee14-AdaptiveAutoConnector][Topology] Snapshot reason=topology_changed ...
```

### Development note

The repository keeps source under `mods-unpacked/guardipee14-AdaptiveAutoConnector` because that is the readable development/source layout. On the tested exported game build, direct loose loading from `res://mods-unpacked/` currently fails with a Mod Loader `Invalid parameter` path error, while the local `mods` ZIP method works correctly.

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Steam Workshop

Workshop packaging is planned after the manual-install build is stable. The same mod source will be used for the Workshop package so manual and Workshop installs do not become separate codebases.

## Development status

v0.1.1 is the first live topology-observer milestone. Its purpose is to reveal the real runtime structures needed for reliable System, Hacking, Coding, Factory, vanilla-resource, and optional-mod adapters before recommendation logic is enabled. See `ROADMAP.md` for the planned implementation sequence.
