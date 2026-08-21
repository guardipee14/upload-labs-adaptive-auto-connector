# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.7  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is a player-controlled connection advisor in development for Upload Labs. The long-term design is to analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player intent must take priority over optimizer score.

## What v0.1.7 does

v0.1.7 remains completely read-only and adds the first native in-game advisor interface on top of the runtime-verified v0.1.6 analysis stack.

- Injects an Adaptive Auto Connector toggle into Upload Labs' native right-side extras toolbar.
- Keeps the advisor closed by default so recommendations never cover the lab unless the player opens it.
- Opens a centered game-themed advisor window using the native `ShadowPanelContainer`, `OverlayPanelTitle`, `MenuPanel`, `ButtonMenu`, and `TabButton` theme variations.
- Shows one recommendation at a time with human-readable module names, the target connector name, source route, resource, advisory score, confidence, tie/unique status, and a scrollable explanation.
- Previous / Next cycle through recommendations without changing topology or learning preference.
- Locate Target closes the advisor, centers the camera on the exact target module instance, and selects it using Upload Labs' native selection system.
- Locate Source does the same for the proposed source module.
- Runtime IDs remain internal for exact diagnostics; the player-facing panel strips numeric instance suffixes such as `heat_sink1` into `Heat Sink`.
- Recommendation selection is preserved across later analysis refreshes when that target still exists.
- No new polling timer is introduced.
- No connection create/delete/register calls are emitted.

The compatibility probe, topology observer, normalized graph, resource model, candidate generator, and candidate scorer remain unchanged from v0.1.6.

## v0.1.7 runtime verification

The native UI went through several real-game test iterations before acceptance:

1. The original floating card loaded but was too large and collided with the right toolbar.
2. A compact floating revision fixed overflow and navigation, but became too small to read comfortably at the player's UI scale.
3. The advisor was moved into Upload Labs' native right sidebar and menus layer.
4. The first module-locate build exposed an outdated three-argument `Globals.set_selection(...)` call and was rejected by Godot 4.6.1 before the presenter could load.
5. The corrected test used the current two-argument selection API and passed.

The accepted test loaded v0.1.7 successfully, attached the native sidebar button and advisor window, and produced real user interaction logs for opening the advisor, moving through recommendations, locating targets, and locating sources.

The Heat Sink case that motivated module location was runtime-verified: Locate Target centered on the exact `heat_sink1` instance and reported `selected=true`. Other target/source pairs also resolved and selected successfully.

During the test the live graph changed from 431 to 433 edges while remaining clean at 235 windows, 870 containers, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.

The recommendation set adjusted with live topology changes: the run began with 13 structural target buckets / 12 recommendations and later moved to 12 target buckets / 11 recommendations as the save changed. The UI stayed synchronized with those updates.

The only `SCRIPT ERROR` in the accepted run remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.

## Scoring semantics

Current scoring remains relative advisory ordering only. Important rules include:

- verified legal candidate: stable base score;
- target currently unserved: route-preservation eligibility;
- positive observed production: limited positive weight;
- provisional `production / required`: capped low-weight hint only;
- shared-source penalty: grows nonlinearly as existing output routes increase;
- trusted Smart Manager headroom/pressure: small capped adjustment only for known manager window/resource pairs;
- final advisory score hard cap: 90.

These values do **not** represent percent efficiency, percent throughput, or expected improvement.

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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.7.zip` into `mods` **without extracting it**.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

Expected UI logging includes:

```text
[guardipee14-AdaptiveAutoConnector][UI] Native sidebar button attached ...
[guardipee14-AdaptiveAutoConnector][UI] User window action='open' ...
[guardipee14-AdaptiveAutoConnector][UI] User preview navigation action='next' ...
[guardipee14-AdaptiveAutoConnector][UI] User locate action='target' window='...' ... selected=true
[guardipee14-AdaptiveAutoConnector][UI] User locate action='source' window='...' ... selected=true
```

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Planned next steps

The next UI refinement is highlighting the exact recommended connector inside a located module so a player does not need to hunt for connector `4`, `File`, `Heat`, or similar internal connector labels after locating the window.

After that, the player-controlled interaction layer can begin adding **Accept**, **Find a different way**, and **No thank you**, with connection execution remaining guarded by explicit player approval and future snapshot/undo protection.

Broader `production`, `required`, and `demand` semantics—and the active Smart Manager headroom path—remain targeted validation work rather than assumed facts.
