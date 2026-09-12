# Speed candidate regression

Run with a portable Godot 4.6.1 console executable:

```powershell
.\tools\Test-SpeedCandidates.ps1 -GodotExecutable 'C:\path\Godot_v4.6.1-stable_win64_console.exe'
```

The runner creates a fresh isolated project under ignored `release/`, copies the actual mod source, and provides test doubles for `Globals.desktop`, `Utils`, windows, resource containers, and manager bindings. It does not load the game, saves, or connection controller.

The 58 checks cover zero-required CPU/GPU speed candidate generation, the actual manager validation/adaptive scoring/explanation pipeline, production/count demand bases, conservative demand, bounded positive/negative scoring, failed-validation/provider fallback, player preference, reconnect removal, live compatibility, connector/resource/route guards, invalid requirements, and ordinary material inputs. These tests do not replace in-game validation of those interfaces.

The original test6 generator excludes `analyzer5/Speed` at its positive-required filter. Test7 admits an unserved `clock_speed` or `gpu_speed` input with a numeric zero requirement while preserving its zero value; it does not fabricate a material cost or capacity ratio. Other zero-required resources remain excluded.

The runner follows Godot's [command-line workflow](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) and treats script/engine errors or a missing success summary as failure.

## Tested package identity

The read-only verifier checks the saved test7 ZIP digest, all 19 runtime files byte-for-byte against local source, the manifest version, and optionally the exact ASM ZIP used in-game:

```powershell
.\tools\Test-ValidatedPackage.ps1 -Archive 'C:\path\guardipee14-AdaptiveAutoConnector-v0.1.15-test7.zip' -AsmArchive 'C:\path\guardipee14-AdaptiveSmartManager-v0.1.0-test20.zip'
```

The identity record is `tests/test7-package.json`. A fresh Git checkout can change line endings and therefore fail the strict byte comparison; that is not proof of a logic regression, but it means the checkout is no longer byte-identical. Do not silently rewrite the recorded digest to accept a rebuilt package. GitHub's ASM test20 download is not the tested archive. See [release handoff](../docs/releases/0.1.15-test7.md).
