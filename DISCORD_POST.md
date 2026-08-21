# [Adaptive Auto Connector] - Adaptive connection advisor - v0.1.0 WIP

**Suggested tags:** `qol`, `wip`

**🧪 Mod name**
Adaptive Auto Connector

**📝 Description**
Adaptive Auto Connector is a WIP player-controlled connection advisor for Upload Labs. The long-term goal is to analyze the player's current layout, explain why another connection may be more efficient, and offer **Accept**, **Find a different way**, or **No thank you** without overriding how the player wants to build.

v0.1.0 is intentionally a read-only compatibility/observer build. It does not change connections yet. It reports active Mod Loader IDs so the next versions can integrate with real runtime identifiers rather than guessed ones.

**⚙️ Features**
• Read-only mod/environment probe
• Lists active Mod Loader IDs for compatibility development
• Detects Taj's Core runtime API when available
• Foundation for System, Hacking, Coding, and Factory analysis
• Planned optional compatibility with Smart Thread Manager, Smart GPU Manager, SmartConnections, and Upload Labs+ (TPU/QPU)
• Future adaptive recommendations will learn from accepted, rejected, alternate, and manual player choices

**🔧 Installation**
Manual/unpacked install for v0.1.0.

Copy:
`guardipee14-AdaptiveAutoConnector`

to:
`SteamLibrary\steamapps\common\Upload Labs\mods-unpacked`

Final path:
`SteamLibrary\steamapps\common\Upload Labs\mods-unpacked\guardipee14-AdaptiveAutoConnector`

No optional compatibility mod is required for the base mod to load.

Target Mod Loader: 7.0.1

**📸 Preview**
No UI preview yet — v0.1.0 is the observer/compatibility foundation.

**⚠️ Known issues / compatibility**
This is a WIP discovery build. Exact integration IDs and hooks for the compatibility mods are still being verified. The current version does not modify game state or make connections.

**🔗 Download**
GitHub: https://github.com/guardipee14/upload-labs-adaptive-auto-connector

**Version:** 0.1.0  
**Game version tested/targeted:** 2.2.12
