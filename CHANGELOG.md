# Changelog

## 0.1.5 - 2026-08-20

### Added
- Read-only candidate scorer layered on top of the runtime-verified v0.1.4 legal candidate generator.
- Relative advisory scoring for verified legality, unserved targets, positive observed production, idle active sources, existing fan-out, and a capped provisional `production / required` hint.
- Confidence labels limited to `low` and `medium`; no `high` confidence is emitted in v0.1.5.
- Read-only explanation engine that selects the highest-ranked candidate per target and emits plain-language reasons.
- Explicit explanation text that advisory scores are not percentage improvements or guaranteed throughput gains.

### Verified
- v0.1.5 loaded successfully with the same 12-mod compatibility stack and reached `v0.1.5 ready` without an Adaptive Auto Connector script error.
- Twelve consecutive scoring cycles each processed 13 target buckets and 100 legal candidates.
- Twelve read-only recommendations were produced on every scoring cycle; the Quantum Processor `qubit` input remained candidate-free and recommendation-free.
- The cold startup scoring sample contained 100 low-confidence and 0 medium-confidence candidates; later samples stabilized at 58 low-confidence and 42 medium-confidence candidates.
- Captured ranked output stayed within the intended conservative range, with later top candidates scoring 78 and no `high` confidence emitted.
- The graph remained clean at 235 windows, 870 containers, 431 edges, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.
- Late repeated scoring/explanation cycles ran alongside roughly 161-164 FPS, with no evidence of the old recurring observer hitch.
- The only `SCRIPT ERROR` remained the unrelated `res://scripts/ad_prompt.gd` undeclared `Ads` parse error.

### Safety / semantics
- v0.1.5 remains fully read-only and does not create, delete, move, or alter connections or save state.
- No additional timer is introduced; scoring reuses the existing approximately 10-second resource-sample path.
- `production / required` remains a capped provisional hint and is not treated as a proven throughput metric.
- Advisory scores are relative ordering values only, not percent efficiency or expected improvement.

## 0.1.4 - 2026-08-20

### Added
- Read-only compatible connection-candidate generator.
- Candidate filtering for exact resource matches, valid connector roles, non-black connectors, self/duplicate rejection, and live game `can_connect()` verification.
- Plain candidate records exposed for later ranking without retaining live game-node references.

### Verified
- Runtime test consistently found 13 unserved required targets, 12 targets with candidates, 100 `verified_can_connect` candidate pairs, 202 structurally rejected pairs, and 0 live-compatibility rejections.
- The Quantum Processor `qubit` input correctly remained at 0 candidates.
- The graph stayed clean at 235 windows, 870 containers, 431 edges, and 72 resources with no edge-consistency failures.
- Later resource/candidate cycles ran around roughly 123-160 FPS without the old recurring hitch.

### Safety
- v0.1.4 remains read-only, adds no timer, and does not emit connection create/delete/register mutation signals.

## 0.1.3 - 2026-08-20

### Added
- Read-only resource model built from the observer's normalized container data and lightweight runtime samples.
- Resource-family classification for the 72 runtime resource IDs observed in the v0.1.2 test save: compute, network, media, coding, hacking, factory, AI, data type, economy, and progression.
- Ten-second runtime sampling of `resource`, `production`, `required`, and optional `demand` values by reusing the existing five-second observer loop; no second polling timer is added.
- Structural observations for required inputs with no current source and active producers with no consumers.
- Experimental connected production/required gap counting for runtime research only; these gaps are not treated as confirmed bottlenecks yet.
- Compact resource catalog and sample summaries, with detailed structural records logged only when the structural set changes.

### Fixed
- Added explicit boolean typing to the topology-change comparison after the first v0.1.3 test exposed a Godot 4.6.1 parser error on Variant inference.

### Verified
- Corrected v0.1.3 test build loaded successfully with the same 12-mod compatibility stack and reached `v0.1.3 ready` without an Adaptive Auto Connector script error.
- Initial graph remained identical to the prior baseline at 233 windows, 861 containers, 423 edges, and 72 resources with 0 dangling, 0 non-reciprocal, and 0 resource-mismatch edges.
- Resource catalog runtime-verified 861 containers, 72 distinct non-empty resource IDs, 0 unknown resources, and family counts of AI 9, Coding 6, Compute 4, Data Type 13, Economy 3, Factory 5, Hacking 10, Media 18, Network 2, and Progression 2.
- The first high-confidence structural observation set contained 13 unserved required inputs, and that count remained stable through all 23 samples while the live topology changed.
- Runtime sampling completed indices 1 through 23; the model tracked container growth from 861 to 870 without losing synchronization.
- The topology graph advanced through 13 revisions and remained structurally clean while live edges increased to 431.
- Late-run samples 21-23 occurred alongside roughly 151-165 FPS, with no evidence in the log of the old recurring sampler-induced frame hitch.
- The only `SCRIPT ERROR` in the corrected run remained the unrelated base-game/other-mod `ad_prompt.gd` undeclared `Ads` parse error.

### Safety / performance
- v0.1.3 remains read-only and does not create, delete, move, or alter connections or game/save state.
- Runtime metric sampling avoids `get_property_list()` and JSON serialization in the periodic hot path.
- Numeric sampling runs every second topology scan (approximately every 10 seconds) to protect the v0.1.1 performance fix.
- Connected `production < required` observations remain experimental and are not yet treated as confirmed bottlenecks.

## 0.1.2 - 2026-08-20

### Added
- Read-only normalized topology graph built from the observer's detailed snapshot.
- Stable plain-data records for windows, resource containers, and directed connection edges.
- Container role classification as `source`, `sink`, `relay`, or `passive` from connector presence.
- Resource and domain-hint indexes for future analyzer lookups.
- Edge-consistency diagnostics for dangling targets, non-reciprocal links, resource mismatches, and duplicate output links.
- Observer signals that publish the initial detailed snapshot and later lightweight topology states to the graph service.
- Live graph synchronization from the existing five-second lightweight observer without adding a second polling loop.

### Changed
- Bumped the WIP manual build to v0.1.2.
- `mod_main.gd` now starts the topology graph before the observer and wires the observer's read-only signals into it.
- Graph logging is compact: one summary per graph revision plus a capped list of edge-consistency issues.

### Verified
- v0.1.2 loaded successfully with the same 12-mod compatibility stack and reached `v0.1.2 ready` without an Adaptive Auto Connector script error.
- The real-save initial observer snapshot and normalized graph matched exactly at 233 windows, 861 containers, and 423 live connections/edges.
- The graph indexed 72 distinct runtime resource IDs and classified 303 source containers, 543 sinks, 0 relays, and 15 passive containers, with 0 unidentified containers.
- Current domain hints resolved to 213 system/unknown windows, 11 Coding candidates, 8 Hacking candidates, and 1 Factory candidate.
- Across eight graph revisions, observer connection counts and graph edge counts stayed synchronized as manual/game rewires moved between 421, 422, and 423 edges.
- Edge validation stayed clean throughout the test: 0 dangling edges, 0 non-reciprocal edges, and 0 resource mismatches; no `Edge issue` lines were emitted.
- The v0.1.1 performance fix remained effective during graph updates; normal gameplay after startup stayed mostly around 150-165 FPS in the captured log without the earlier repeating frame hitch.

### Known external log noise
- Current sessions still show the existing base-game/other-mod `ad_prompt.gd` parse error for undeclared `Ads` and SmartConnections `connection_droppped` callback-arity errors. These are outside Adaptive Auto Connector.

### Safety
- v0.1.2 remains read-only and does not create, delete, move, or alter connections, windows, saves, coding, hacking, or factory state.
- The graph stores normalized data rather than retaining game-node references.
- The observer/graph path does not emit connection mutation signals or re-register resources.

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
- First runtime topology test observed 231 windows, 856 containers, and 417 connections and detected later changes to 418 and 419 connections.
- Optimized performance test observed 233 windows, 861 containers, and 419 initial connections and detected live rewires as the count advanced to 420, 421, and 423 connections.
- The optimized five-second lightweight observer eliminated the repeating every-few-seconds frame drop reported with the original two-second detailed rescan.
- The `disassembler` false-positive fix was runtime-verified; it now remains `system_or_unknown` instead of being labeled Factory.
- Runtime discovery confirmed Smart Thread Manager exposes `clock_speed` demand through its smart resource container and Smart GPU Manager exposes `gpu_speed` demand.
- Runtime discovery confirmed Hacking resources including `hack_power`, `payload_damage`, `infection_damage`, and `hack_experience`.
- Runtime discovery confirmed Coding resources including `code_bugfix`, `code_optimization`, `code_speed`, and `contribution`.
- Runtime discovery confirmed a Factory `router_assembler` using `pcb`, `router`, and `work_speed`.
- Verified optional IDs: `Helios-SmartConnections`, `kuuk-SmartThreadManager`, `kuuk-SmartGPUManager`, `TajemnikTV-Core`, `chingcm-ModUtils`, and `chingcm-UploadLabsPlus`.

### Known external log noise
- Current test sessions still show a base-game/other-mod `ad_prompt.gd` parse error for undeclared `Ads` and SmartConnections `connection_droppped` callback-arity errors. These occur outside Adaptive Auto Connector and are not emitted by its observer.

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
