# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.5  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is a player-controlled connection advisor in development for Upload Labs. The long-term design is to analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player intent must take priority over optimizer score.

## What v0.1.5 does

v0.1.5 remains completely read-only. It keeps the runtime-verified topology observer, normalized graph, resource model, and legal candidate generator, then adds a scoring and explanation layer that:

- ranks only candidates already accepted by the live game's `can_connect()` check;
- uses a relative advisory score, never a percentage efficiency or promised throughput gain;
- gives verified legality and an unserved target the stable base score;
- adds limited weight for positive observed source production;
- gives an idle active source a small bonus;
- applies a small penalty for existing source fan-out;
- uses `production / required` only as a capped provisional capacity hint while those semantics remain under validation;
- limits confidence to `low` or `medium`; v0.1.5 never emits `high` confidence;
- selects the highest-ranked candidate per target and emits plain-language reasons;
- keeps recommendations read-only and does not create, delete, or move any connection;
- reuses the existing approximately 10-second resource sample path and adds no second timer.

The tested v0.1.4 candidate generator remains unchanged, keeping legality separate from ranking quality.

## Runtime verification

The v0.1.5 real-save test passed with the same 12-mod compatibility stack and reached `v0.1.5 ready` without an Adaptive Auto Connector script error.

Across 12 consecutive scoring cycles, the pipeline consistently reported:

- 13 target buckets;
- 100 scored legal candidates;
- 12 read-only recommendations;
- the Quantum Processor's unserved `qubit` input still at 0 candidates/recommendations;
- startup sample: 100 low-confidence / 0 medium-confidence candidates while production was still cold;
- later samples: 58 low-confidence / 42 medium-confidence candidates;
- observed advisory scores from the captured ranked output remained within the intended conservative range, with later top examples at 78 and no `high` confidence emitted.

The explanation engine explicitly states that the score is relative and not a percentage improvement or guaranteed throughput gain. For active sources it also labels the observed `production / required` ratio as a capped provisional hint rather than a proven throughput estimate.

The normalized graph remained clean at 235 windows, 870 containers, 431 edges, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.

After the startup/loading phase, repeated scoring/explanation cycles ran alongside roughly 161-164 FPS near the end of the captured session, with no evidence of the old recurring observer hitch. The only `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` error outside Adaptive Auto Connector.

## Scoring semantics

Current relative score components are intentionally simple and conservative:

- verified legal candidate: +50
- target currently unserved: +10
- positive observed production: +10
- active source with no current outputs: +10
- provisional capped capacity hint: up to +10
- existing source fan-out: -2 per output, capped at -10

These values only order legal candidates. They do **not** represent percent efficiency, percent throughput, or expected improvement.

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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.5.zip` into `mods` **without extracting it**.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

Expected scoring/explanation logging includes:

```text
[guardipee14-AdaptiveAutoConnector][Scoring] Sample index=... targets=... scored_candidates=... confidence_low=... confidence_medium=...
[guardipee14-AdaptiveAutoConnector][Scoring]     Ranked rank=1 score=... confidence='...'
[guardipee14-AdaptiveAutoConnector][Explain] Sample index=... recommendations=... mode='read_only'
[guardipee14-AdaptiveAutoConnector][Explain]     Why: ...
```

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Planned next steps

v0.1.5 is runtime-verified. The next work is to improve recommendation quality using stronger capacity/demand semantics and topology/player-preservation context, then prepare the first suggestion UI with **Accept**, **Find a different way**, and **No thank you**. Connection execution remains a later, explicitly approved step.
