[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release')
)

$ErrorActionPreference = 'Stop'

$modFolderName = 'guardipee14-AdaptiveAutoConnector'
$version = '0.1.12'
$source = Join-Path $ProjectRoot "mods-unpacked\$modFolderName"
$staging = Join-Path $OutputDirectory 'staging'
$archive = Join-Path $OutputDirectory "$modFolderName-v$version.zip"

if (-not (Test-Path -LiteralPath $source)) {
    throw "Mod source folder was not found: $source"
}

Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $staging 'mods-unpacked') -Force | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $staging 'mods-unpacked') -Recurse -Force

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $staging 'mods-unpacked') -DestinationPath $archive -CompressionLevel Optimal
Remove-Item -LiteralPath $staging -Recurse -Force

Write-Host "Created: $archive"
