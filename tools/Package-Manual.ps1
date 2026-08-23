[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modFolderName = 'guardipee14-AdaptiveAutoConnector'
$source = Join-Path $ProjectRoot "mods-unpacked/$modFolderName"
$manifestPath = Join-Path $source 'manifest.json'
$staging = Join-Path $OutputDirectory 'staging'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Mod source folder was not found: $source"
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Mod manifest was not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$version = [string]$manifest.version_number

if ([string]::IsNullOrWhiteSpace($version)) {
    throw 'manifest.json does not contain version_number.'
}

if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Manifest version is not valid semantic versioning: $version"
}

$archive = Join-Path $OutputDirectory "$modFolderName-v$version.zip"

Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $staging 'mods-unpacked') -Force | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $staging 'mods-unpacked') -Recurse -Force

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $staging 'mods-unpacked') -DestinationPath $archive -CompressionLevel Optimal
Remove-Item -LiteralPath $staging -Recurse -Force

Write-Host "Created: $archive"
