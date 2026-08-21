# Roadmap

## v0.1.x - Observer foundation
- [x] Manual ZIP mod structure
- [x] Safe load entry point
- [x] Active mod ID probe
- [x] Taj's Core runtime presence probe
- [x] Confirm exact ID for Smart Thread Manager
- [x] Confirm exact ID for Smart GPU Manager
- [x] Confirm exact ID for SmartConnections
- [x] Confirm exact IDs for Upload Labs+ and ModUtils
- [x] Identify safe vanilla topology structures used by live mods (`Globals.desktop`, `Windows`, `WindowBase.containers`, ResourceContainer link IDs)
- [x] Implement read-only window/container/connection snapshotting
- [x] Implement topology-change detection without mutation signals
- [x] Runtime-verify v0.1.1 topology observer on a real save
- [x] Eliminate periodic observer frame drops with lightweight delta polling
- [ ] Identify authoritative workspace/domain markers for System, Hacking, Coding, and Factory
- [x] Identify and classify the current save's 72 observed runtime resource IDs

## v0.2.x - Read-only topology advisor
- [x] Define normalized window/container/edge records
- [x] Classify connector roles (`source`, `sink`, `relay`, `passive`)
- [x] Build normalized topology graph
- [x] Runtime-verify v0.1.2 normalized graph on a real save
- [x] Validate edge consistency rules against the current vanilla + compatibility-mod save
- [x] Classify observed resource IDs into broad resource families
- [x] Implement first read-only structural bottleneck observations
- [x] Runtime-verify v0.1.3 resource sampling and structural observations
- [ ] Validate `production`, `required`, and `demand` semantics before using connected-gap metrics as confirmed bottlenecks
- [x] Generate compatible connection candidates
- [x] Runtime-verify v0.1.4 live `can_connect()` candidate generation
- [x] Rank candidates with conservative relative advisory scoring
- [x] Explain why a candidate is preferred without claiming percentage efficiency
- [x] Runtime-verify v0.1.5 scoring/explanation pipeline on a real save
- [ ] Add stronger capacity/demand semantics and topology-preservation scoring

## v0.3.x - Player-controlled connector
- [ ] Suggestion UI
- [ ] Accept
- [ ] Find a different way
- [ ] No thank you
- [ ] Snapshot before changes
- [ ] Undo accepted changes

## v0.4.x - Adaptive preferences
- [ ] Learn from accepted suggestions
- [ ] Learn from alternate requests
- [ ] Learn from rejections
- [ ] Observe manual connection choices
- [ ] Suppress repetitive suggestions

## v0.5.x - Domain intelligence
- [ ] Hacking analyzer
- [ ] Coding analyzer
- [ ] Factory analyzer
- [ ] Cross-domain recommendation scoring

## v0.6.x - Expanded mod compatibility
- [ ] Smart Thread Manager CPU-demand adapter
- [ ] Smart GPU Manager GPU-demand adapter
- [ ] SmartConnections cooperation/observation adapter
- [ ] Upload Labs+ TPU/QPU adapter
- [ ] Known-version conflict rules
- [ ] Optional Taj's Core service backend

## v1.0.0 - Stable advisor
- [ ] Manual-install stable release
- [ ] Steam Workshop release
- [ ] Versioned compatibility matrix
- [ ] User-facing settings and diagnostics
