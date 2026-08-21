# [Adaptive Auto Connector] - Adaptive connection advisor - v0.1.0 WIP

**Suggested tags:** `qol`, `wip`

**🧪 Mod name**
Adaptive Auto Connector

**📝 Description**
Adaptive Auto Connector is a WIP player-controlled connection advisor for Upload Labs. The long-term goal is to analyze the player's current layout, explain why another connection may be more efficient, and offer **Accept**, **Find a different way**, or **No thank you** without overriding how the player wants to build.

v0.1.0 is intentionally a read-only compatibility/observer build. It does not change connections yet. It reports active Mod Loader IDs and verifies the optional compatibility environment we will build adapters against.

**⚙️ Features**
• Read-only mod/environment probe
• Lists active Mod Loader IDs
• Detects Taj's Core runtime API when available
• Foundation for System, Hacking, Coding, and Factory analysis
• Verified optional IDs for Smart Thread Manager, Smart GPU Manager, SmartConnections, Upload Labs+, ModUtils, and Taj's Core
• Planned TPU/QPU awareness through Upload Labs+
• Future adaptive recommendations will learn from accepted, rejected, alternate, and manual player choices

**🔧 Installation**
Manual/local ZIP install for v0.1.0.

Create if needed:
`SteamLibrary\steamapps\common\Upload Labs\mods`

Copy the release ZIP there **without extracting it**:
`guardipee14-AdaptiveAutoConnector-v0.1.0.zip`

Final path:
`SteamLibrary\steamapps\common\Upload Labs\mods\guardipee14-AdaptiveAutoConnector-v0.1.0.zip`

No optional compatibility mod is required for the base mod to load.

Target Mod Loader: 7.0.1

**📸 Preview**
No UI preview yet — v0.1.0 is the observer/compatibility foundation.

**⚠️ Known issues / compatibility**
This is a WIP observer build. It does not modify game state or make connections.

The tested exported game build reports an `Invalid parameter` error when trying to load the loose `res://mods-unpacked/` directory, so the verified manual installation method is the local `mods` ZIP method above.

Smart Thread Manager 3.0.0 and Smart GPU Manager 3.0.0 currently warn that the installed game version is outside their declared compatibility range, although both continue loading.

**🔗 Download**
GitHub: https://github.com/guardipee14/upload-labs-adaptive-auto-connector

**Version:** 0.1.0  
**Game version tested/targeted:** 2.2.12
