# Adaptive Auto Connector for Upload Labs

**Status:** WIP / experimental  
**Current version:** 0.1.6  
**Target game version:** Upload Labs 2.2.12  
**Target mod loader:** Godot Mod Loader 7.0.1  
**Repository:** https://github.com/guardipee14/upload-labs-adaptive-auto-connector

Adaptive Auto Connector is a player-controlled connection advisor in development for Upload Labs. The long-term design is to analyze the current layout, explain why a connection may be more efficient, and let the player choose **Accept**, **Find a different way**, or **No thank you**. Player intent must take priority over optimizer score.

## What v0.1.6 does

v0.1.6 remains completely read-only. It keeps the runtime-verified observer, normalized graph, resource model, and legal candidate generator, then hardens the scoring/explanation layer by:

- applying nonlinear shared-source penalties so heavily fan-out producers lose ground to otherwise similar sources with fewer existing player routes;
- recording explicit route-preservation metadata and never replacing an already-served target route;
- detecting top-score ambiguity with `unique_top` and `tied_top` selection states;
- reporting the number of tied top candidates and the score gap to the next distinct choice;
- explaining that deterministic tie-breaking is only stable ordering, not proof that the first tied source is better;
- preserving the existing relative-score semantics: scores are not percentages or promised throughput gains;
- keeping confidence limited to `low` or `medium`;
- hard-capping advisory scores at 90;
- adding a narrowly scoped Smart Thread/GPU Manager headroom hook that only applies to known manager windows/resources when live `count` and `demand` are readable;
- reusing the existing approximately 10-second sample path and adding no new timer;
- never creating, deleting, moving, or replacing a connection.

The lower read-only layers from v0.1.5 remain unchanged.

## Runtime verification

The v0.1.6 real-save test passed with the same 12-mod compatibility stack and reached `v0.1.6 ready` without an Adaptive Auto Connector script error.

Across 13 consecutive scoring cycles, the pipeline consistently reported:

- 13 target buckets;
- 100 scored legal candidates;
- 12 read-only recommendations;
- 1 `unique_top` recommendation and 11 `tied_top` recommendations;
- startup sample: 100 low-confidence / 0 medium-confidence candidates;
- later samples: 58 low-confidence / 42 medium-confidence candidates;
- the Quantum Processor's unserved `qubit` input remained at 0 candidates/recommendations;
- captured top advisory scores remained at or below 76, beneath the hard 90 cap;
- no `high` confidence output.

Tie handling was runtime-verified. For example, trainer inputs had ten candidates sharing the same top score, and the explanation explicitly stated that the first listed source was only selected by deterministic tie-breaking rather than being proven superior. `code_hashmap0/String` remained a true unique-top case because it had one legal candidate.

The normalized graph remained clean at 235 windows, 870 containers, 431 edges, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.

The run included an early sustained low-FPS period around a large topology/container churn event; the slowdown persisted between samples rather than recurring only when scoring ran. Later scoring cycles 10-13 repeatedly ran alongside roughly 159-167 FPS, so the captured log does not show the old periodic sample-induced hitch.

The Smart Manager-specific headroom hook was **not exercised** by this save because none of the current unserved required targets used `clock_speed` or `gpu_speed`; logged ranked candidates therefore reported `manager_status='not_applicable'`. The manager hook remains conservative and source-grounded, but its active runtime path still needs a future targeted test.

The only `SCRIPT ERROR` remained the pre-existing `res://scripts/ad_prompt.gd` undeclared `Ads` parse error outside Adaptive Auto Connector.

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
4. Copy `guardipee14-AdaptiveAutoConnector-v0.1.6.zip` into `mods` **without extracting it**.
5. Remove older Adaptive Auto Connector ZIPs so only one version with the same Mod Loader ID is present.
6. Launch Upload Labs and load a save.

Expected scoring/explanation logging includes:

```text
[guardipee14-AdaptiveAutoConnector][Scoring] Sample index=... targets=... scored_candidates=... confidence_low=... confidence_medium=... unique_top=... tied_top=...
[guardipee14-AdaptiveAutoConnector][Scoring]   Target ... selection='tied_top' tied_top=... gap=...
[guardipee14-AdaptiveAutoConnector][Explain] Sample index=... recommendations=... unique_top=... tied_top=... mode='read_only'
[guardipee14-AdaptiveAutoConnector][Explain]     Why: ...
```

## Safety philosophy

Future automatic connection behavior will be opt-in. The project rule is:

> Player intent > optimizer score.

The advisor must explain a recommendation and receive approval before changing the player's network.

## Planned next steps

v0.1.6 is runtime-verified for route-preserving scoring and ambiguity handling. The next major milestone is the first player-facing suggestion UI with **Accept**, **Find a different way**, and **No thank you**, while connection execution remains a later explicitly approved step. Broader `production`, `required`, and `demand` semantics—and the active Smart Manager headroom path—remain targeted validation work rather than assumed facts.
