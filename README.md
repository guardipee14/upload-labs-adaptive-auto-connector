# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.0  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is planned as a player-controlled connection advisor for Upload Labs. It will analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player decisions and manual connection choices will influence future suggestions instead of being overridden.

## What v0.1.0 does

This first release is deliberately read-only. It:

- loads as an unpacked Upload Labs mod;
- reports active Mod Loader mod IDs to the game log;
- probes for likely compatibility candidates;
- detects Taj's Core runtime metadata when available;
- makes **no connection, topology, save, coding, hacking, or factory changes**.

The probe output is intended to give us the exact runtime identifiers needed to build reliable adapters instead of guessing them.

## Planned core support

- Main Upload Labs system/network connections
- Hacking
- Coding
- Factory
- CPU, GPU, storage, network, and other vanilla resources
- Explainable suggestions with Accept / Find a different way / No thank you
- Dynamic preference learning from accepted, rejected, alternate, and manual choices
- Undo/snapshot protection before any future automatic change

## Planned optional compatibility

- Smart Thread Manager by kuuk
- Smart GPU Manager by kuuk
- SmartConnections - Drag and Drop Anywhere! by helios
- Upload Labs+ by chingcm, including TPU and QPU awareness
- Upload Labs+ Dev Utils when present/needed
- Taj's Mods - Core (Library), preferably as an optional service provider rather than a hard dependency

No compatibility mod is required for the base mod to load.

## Manual installation

1. Close Upload Labs.
2. Find the game's installation folder. A typical Steam library path is:

   `SteamLibrary\steamapps\common\Upload Labs`

3. Copy this folder:

   `mods-unpacked\guardipee14-AdaptiveAutoConnector`

   into:

   `SteamLibrary\steamapps\common\Upload Labs\mods-unpacked`

4. The final layout must be:

```text
Upload Labs
└─ mods-unpacked
   └─ guardipee14-AdaptiveAutoConnector
      ├─ manifest.json
      ├─ mod_main.gd
      └─ compatibility
         └─ compatibility_probe.gd
```

5. Launch Upload Labs.
6. Check the game/mod-loader log for lines beginning with:

   `[guardipee14-AdaptiveAutoConnector]`

For v0.1.0, please capture the active mod ID list when testing with the compatibility mods installed. Those IDs will be used to replace discovery heuristics with exact adapter matching.

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Steam Workshop

Workshop packaging is planned after the manual-install build is stable. Godot Mod Loader 7.0.1 has native Steam Workshop support, so this repository is structured to keep that future path straightforward.

## Development status

v0.1.0 is a compatibility-discovery milestone, not the finished advisor. See `ROADMAP.md` for the planned implementation sequence.
