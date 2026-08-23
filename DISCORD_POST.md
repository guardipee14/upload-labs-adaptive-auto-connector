# [Adaptive Auto Connector] - Adaptive player-controlled connection advisor - v0.1.14 WIP

**Suggested tags:** `qol`, `wip`

**🧪 Mod name**
Adaptive Auto Connector

**📝 Description**
Adaptive Auto Connector is an experimental player-controlled connection advisor for Upload Labs. It analyzes the live topology, ranks legal routes, explains why a route may be preferable, learns from confirmed player choices, and always leaves the final decision to the player.

> **Player intent > optimizer score.**

**✨ What’s new in v0.1.14**
• In-advisor learned-preference diagnostics with schema/persistence status
• Per-route score, event history, age, ACTIVE/QUIET state, and soft-suppression status
• Persistent learning from **Accept**, strict manual connections, **Find different way**, **No thank you**, and **Undo**
• Reversible soft suppression for repeatedly rejected suggestions without hiding legal alternatives
• **Reset Selected** for one learned route
• Two-click **Reset All / Confirm Reset All** safety flow
• Guarded **Accept connection** revalidates the exact live route before creating anything
• Undo and AAC-owned changes are tracked so manual-choice learning is not double-counted

**🛡️ Safety / verification**
• Reset/diagnostics actions do **not** create or delete connections
• Unknown newer preference schemas are protected from destructive downgrade/reset behavior
• Runtime-tested on Godot 4.6.1 with the existing 12-mod compatibility stack
• Full restart test confirmed reset persistence
• Captured graph after restart: **454 edges, 0 dangling, 0 non-reciprocal, 0 resource-mismatch edges**
• No recurring diagnostics hitch identified in the captured run

**🔧 Installation**
Copy the ZIP into:
`SteamLibrary\steamapps\common\Upload Labs\mods`

Leave it **unextracted** and remove older Adaptive Auto Connector ZIPs with the same Mod Loader ID.

ZIP name:
`guardipee14-AdaptiveAutoConnector-v0.1.14.zip`

**⚠️ WIP note**
Scoring is still conservative advisory ordering, not a guaranteed throughput or percentage-improvement claim. Broader production/required/demand semantics and deeper Hacking, Coding, Factory, and Smart Manager behavior are still being validated.

**🔗 GitHub**
https://github.com/guardipee14/upload-labs-adaptive-auto-connector

**Version:** 0.1.14  
**Game version:** Upload Labs 2.2.12  
**Target Mod Loader:** 7.0.1
