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
- [x] Identify and classify the current save's observed runtime resource IDs

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
- [x] Add route-preservation scoring and nonlinear shared-source protection
- [x] Add explicit top-score ambiguity/tie handling
- [x] Runtime-verify v0.1.6 route-preserving scoring and ambiguity handling
- [ ] Targeted runtime-test the active Smart Thread/GPU Manager headroom adjustment

## v0.3.x - Player-controlled connector
- [x] Suggestion UI read-only preview foundation
- [x] Runtime-verify v0.1.7 native suggestion UI, preview controls, and module locate actions
- [x] Highlight the exact recommended connector within a located module
- [x] Runtime-verify v0.1.8 exact target/source connector highlighting
- [x] Accept
- [x] Find a different way
- [x] No thank you
- [x] Snapshot before changes
- [x] Undo accepted changes
- [x] Runtime-verify v0.1.9 guarded Accept -> one-edge create -> Undo -> prior edge count
- [x] Runtime-verify changed-topology Accept refusal without mutation

## v0.4.x - Adaptive preferences
- [x] Learn from accepted suggestions
- [x] Learn from alternate requests
- [x] Learn from rejections
- [x] Treat quick Undo as negative preference feedback
- [x] Bound preference influence so learned score cannot override candidate legality or guarded Accept
- [x] Use semantic preference keys that survive numbered-instance/runtime-ID churn
- [x] Runtime-verify v0.1.10 preference events and later ranking changes on a real save
- [x] Observe manual connection choices
- [x] Runtime-verify v0.1.11 strict manual additions and AAC-owned Accept/Undo self-suppression on a real save
- [x] Persist learned preferences across game sessions with versioned/schema-safe storage
- [x] Runtime-verify v0.1.12 schema-1 save -> full restart -> restore-before-scoring round trip
- [x] Runtime-verify existing-primary backup/write path with a post-restart preference update
- [x] Soft-suppress repetitive suggestions from the default slot without creating permanent global rejection
- [x] Require score `<= -5` plus at least two negative feedback events before persistent soft suppression
- [x] Keep soft-suppressed routes legal and reachable through explicit `Find different way` navigation
- [x] Fall back to a legal route when every candidate for a target is soft-suppressed
- [x] Runtime-verify v0.1.13 threshold crossing, explicit player override, and restart reconstruction from schema-1 history
- [x] Add user-facing learned-preference/settings diagnostics and reset controls
- [x] Show schema/store status, learned semantic route list, score/event/suppression details, and age in the existing scrollable advisor UI
- [x] Add backup-safe single-route reset without topology mutation
- [x] Add two-click reset-all confirmation and future-schema destructive-reset protection
- [x] Runtime-verify v0.1.14 Reset Selected -> ranking refresh -> Reset All -> full restart with empty schema-1 state

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
- [x] User-facing settings and diagnostics
