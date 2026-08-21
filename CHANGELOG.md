# Changelog

## Unreleased

### Changed
- Replaced heuristic compatibility matching with exact runtime mod IDs verified from a real Upload Labs session.
- Renamed the Upload Labs+ helper integration to `Upload Labs+ ModUtils` and detect it as `chingcm-ModUtils`.
- Updated manual installation instructions to use the verified local `mods` ZIP method.

### Verified
- Adaptive Auto Connector v0.1.0 is discovered, initialized, and reaches `v0.1.0 ready` without an Auto Connector script error.
- Verified optional IDs: `Helios-SmartConnections`, `kuuk-SmartThreadManager`, `kuuk-SmartGPUManager`, `TajemnikTV-Core`, `chingcm-ModUtils`, and `chingcm-UploadLabsPlus`.

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
