# Changelog

## 0.1.1 - 2026-08-20

### Added
- Read-only topology observer for live Upload Labs windows and resource containers.
- Initial detailed snapshot after `Globals.desktop/Windows` becomes available.
- Lightweight periodic topology fingerprinting with compact delta logging.
- Container discovery for IDs, inputs, outputs, connector presence, connector color, scene/script paths, and selected runtime properties.
- Discovery-only domain hints for likely System/Hacking/Coding/Factory windows.

### Changed
- Replaced the original two-second full detailed rescan with a five-second lightweight connection/topology fingerprint after runtime testing showed visible frame drops.
- Topology changes now report only added/removed windows, added/removed containers, and rewired containers instead of dumping the entire graph again.
- Tightened domain hints so `disassembler` is no longer incorrectly classified as Factory merely because its name contains `assembler`.
- Replaced heuristic compatibility matching with exact runtime mod IDs verified from a real Upload Labs session.
- Renamed the Upload Labs+ helper integration to `Upload Labs+ ModUtils` and detect it as `chingcm-ModUtils`.
- Updated manual installation instructions to use the verified local `mods` ZIP method.

### Verified
- Adaptive Auto Connector v0.1.1 loaded successfully with 12 active mods and reached `v0.1.1 ready` without an Auto Connector script error.
- Initial runtime topology observed 231 windows, 856 containers, and 417 connections.
- The observer detected live topology changes, including connection-count changes from 417 to 418 and then 419.
- Runtime discovery confirmed Smart Thread Manager exposes `clock_speed` demand through its smart resource container and Smart GPU Manager exposes `gpu_speed` demand.
- Runtime discovery confirmed Hacking resources including `hack_power`, `payload_damage`, `infection_damage`, and `hack_experience`.
- Runtime discovery confirmed Coding resources including `code_bugfix`, `code_optimization`, `code_speed`, and `contribution`.
- Runtime discovery confirmed a Factory `router_assembler` using `pcb`, `router`, and `work_speed`.
- Verified optional IDs: `Helios-SmartConnections`, `kuuk-SmartThreadManager`, `kuuk-SmartGPUManager`, `TajemnikTV-Core`, `chingcm-ModUtils`, and `chingcm-UploadLabsPlus`.

### Safety
- v0.1.1 does not create, delete, move, or alter connections, windows, saves, coding, hacking, or factory state.
- The topology observer does not emit connection mutation signals or re-register resources.

## 0.1.0 - 2026-08-20

### Added
- Initial manual-install Upload Labs mod layout.
- Read-only `mod_main.gd` entry point.
- Compatibility probe that lists active Mod Loader IDs.
- Heuristic discovery hints for planned compatibility mods.
- Optional Taj's Core runtime API presence check.
- Manual installation documentation and development roadmap.

### Safety
- This version does not create, delete, move, or alter connections or game state.
