[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GodotExecutable,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# A fresh isolated project per run, with only test doubles for game singletons.
# No game executable, saves, Steam services or connection controller are loaded.
$testRuntime = Join-Path $ProjectRoot ('release/headless-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRuntime | Out-Null
Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'tests/headless') -File |
    Copy-Item -Destination $testRuntime
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'mods-unpacked') -Destination $testRuntime -Recurse
$logPath = Join-Path $testRuntime 'regression.log'

& $GodotExecutable --headless --path $testRuntime --log-file $logPath --script res://test_speed_candidates.gd
$testExitCode = $LASTEXITCODE
if ($testExitCode -ne 0) { throw "Godot regression failed with exit $testExitCode. Log: $logPath" }
if (-not (Select-String -LiteralPath $logPath -Pattern 'AAC REGRESSION: [1-9][0-9]* checks, 0 failures' -Quiet)) {
    throw "Missing successful regression summary. Log: $logPath"
}
if (Select-String -LiteralPath $logPath -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) {
    throw "Godot reported an error despite the test exit status. Log: $logPath"
}
Write-Output "Verified regression log: $logPath"
