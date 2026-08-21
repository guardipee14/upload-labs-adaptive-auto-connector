# Changelog

## 0.1.1 - 2026-08-20

### Added
- Read-only topology observer for live Upload Labs windows and resource containers.
- Initial snapshot after `Globals.desktop/Windows` becomes available.
- Two-second read-only topology polling with change-only logging.
- Container discovery for IDs, inputs, outputs, connector presence, connector color, scene/script paths, and selected runtime properties.
- Discovery-only domain hints for likely System/Hacking/Coding/Factory windows.

### Changed
- Replaced heuristic compatibility matching with exact runtime mod IDs verified from a real Upload Labs session.
- Renamed the Upload Labs+ helper integration to `Upload Labs+ ModUtils` and detect it as `chingcm-ModUtils`.
- Updated manual installation instructions to use the verified local `mods` ZIP method.

### Verified
- Adaptive Auto Connector v0.1.0 was discovered, initialized, and reached `v0.1.0 ready` without an Auto Connector script error.
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
