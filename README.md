# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.0  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is planned as a player-controlled connection advisor for Upload Labs. It will analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player decisions and manual connection choices will influence future suggestions instead of being overridden.

## What v0.1.0 does

This first release is deliberately read-only. It:

- loads as a local ZIP mod;
- reports active Mod Loader mod IDs to the game log;
- detects verified optional compatibility mods by exact runtime ID;
- detects Taj's Core runtime metadata when available;
- makes **no connection, topology, save, coding, hacking, or factory changes**.

v0.1.0 has been successfully runtime-tested with the compatibility stack listed below. The observer completed and reached `v0.1.0 ready` without an Auto Connector script error.

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

4. Copy the release ZIP into that folder **without extracting it**:

   `guardipee14-AdaptiveAutoConnector-v0.1.0.zip`

5. The verified layout is:

```text
Upload Labs
└─ mods
   └─ guardipee14-AdaptiveAutoConnector-v0.1.0.zip
```

6. Launch Upload Labs.
7. Check the game/mod-loader log for lines beginning with:

   `[guardipee14-AdaptiveAutoConnector]`

A successful v0.1.0 startup ends with:

```text
[guardipee14-AdaptiveAutoConnector] Probe complete. No game state was modified.
[guardipee14-AdaptiveAutoConnector] v0.1.0 ready.
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

v0.1.0 is a compatibility-discovery milestone, not the finished advisor. See `ROADMAP.md` for the planned implementation sequence.
