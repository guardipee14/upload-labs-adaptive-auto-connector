[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Publish,
    [switch]$Draft,
    [switch]$Prerelease,
    [string]$Repository = $env:GITHUB_REPOSITORY
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modFolderName = 'guardipee14-AdaptiveAutoConnector'
$manifestPath = Join-Path $ProjectRoot "mods-unpacked/$modFolderName/manifest.json"
$sourcePath = Join-Path $ProjectRoot "mods-unpacked/$modFolderName"
$releaseDirectory = Join-Path $ProjectRoot 'release'
$readmePath = Join-Path $ProjectRoot 'README.md'
$discordPostPath = Join-Path $ProjectRoot 'DISCORD_POST.md'
$changelogPath = Join-Path $ProjectRoot 'CHANGELOG.md'

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command was not found: $Name"
    }
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$output"
    }

    return $output
}

function Get-MarkdownSection {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Heading
    )

    $escapedHeading = [regex]::Escape($Heading)
    $pattern = "(?ms)^##\s+$escapedHeading\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)

    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

Assert-Command -Name 'git'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest was not found: $manifestPath"
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Mod source folder was not found: $sourcePath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$version = [string]$manifest.version_number

if ([string]::IsNullOrWhiteSpace($version)) {
    throw 'manifest.json does not contain version_number.'
}

if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Manifest version is not valid semantic versioning: $version"
}

$tag = "v$version"
$repoRoot = (Invoke-Git -Arguments @('-C', $ProjectRoot, 'rev-parse', '--show-toplevel')).Trim()
$commit = (Invoke-Git -Arguments @('-C', $ProjectRoot, 'rev-parse', 'HEAD')).Trim()
$branch = (Invoke-Git -Arguments @('-C', $ProjectRoot, 'branch', '--show-current')).Trim()
$status = @(Invoke-Git -Arguments @('-C', $ProjectRoot, 'status', '--porcelain'))
$dirty = $status.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace(($status -join ''))

if ($dirty) {
    throw 'Release builds require a clean working tree.'
}

if (Test-Path -LiteralPath $readmePath) {
    $readme = Get-Content -LiteralPath $readmePath -Raw
    if ($readme -notmatch [regex]::Escape("Current version:** $version")) {
        throw "README.md does not identify $version as the current version."
    }
}

if (Test-Path -LiteralPath $discordPostPath) {
    $discordPost = Get-Content -LiteralPath $discordPostPath -Raw
    if ($discordPost -notmatch [regex]::Escape("v$version")) {
        throw "DISCORD_POST.md does not reference v$version."
    }
}

if (Test-Path -LiteralPath $changelogPath) {
    $changelog = Get-Content -LiteralPath $changelogPath -Raw
    if ($changelog -notmatch "(?m)^##\s+(?:v)?$([regex]::Escape($version))\b") {
        Write-Warning "CHANGELOG.md does not yet contain a v$version section."
    }
}

New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null

$archiveName = "$modFolderName-v$version.zip"
$archivePath = Join-Path $releaseDirectory $archiveName
$checksumPath = "$archivePath.sha256"
$notesPath = Join-Path $releaseDirectory "$modFolderName-v$version-release-notes.md"
$stagingPath = Join-Path $releaseDirectory "staging-$version"

Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $checksumPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $notesPath -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path (Join-Path $stagingPath 'mods-unpacked') -Force | Out-Null
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $stagingPath 'mods-unpacked') -Recurse -Force
Compress-Archive -Path (Join-Path $stagingPath 'mods-unpacked') -DestinationPath $archivePath -CompressionLevel Optimal
Remove-Item -LiteralPath $stagingPath -Recurse -Force

$hash = Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
$sha256 = $hash.Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$sha256  $archiveName" -Encoding ascii

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $manifestEntryPath = "mods-unpacked/$modFolderName/manifest.json"
    $manifestEntry = $zip.GetEntry($manifestEntryPath)

    if ($null -eq $manifestEntry) {
        throw "Release archive does not contain expected manifest: $manifestEntryPath"
    }

    $reader = [System.IO.StreamReader]::new($manifestEntry.Open())
    try {
        $archiveManifest = $reader.ReadToEnd() | ConvertFrom-Json
    }
    finally {
        $reader.Dispose()
    }

    if ([string]$archiveManifest.version_number -ne $version) {
        throw "Archive manifest version '$($archiveManifest.version_number)' does not match '$version'."
    }
}
finally {
    $zip.Dispose()
}

$releaseNotes = "# Adaptive Auto Connector v$version`n`n"
$releaseNotes += "**Commit:** ``$commit```n`n"

if (Test-Path -LiteralPath $readmePath) {
    $readme = Get-Content -LiteralPath $readmePath -Raw
    $whatSection = Get-MarkdownSection -Content $readme -Heading "What v$version does"
    $verificationSection = Get-MarkdownSection -Content $readme -Heading "v$version runtime verification"
    $installationSection = Get-MarkdownSection -Content $readme -Heading 'Manual installation'

    if ($whatSection) {
        $releaseNotes += "## What's new`n`n$whatSection`n`n"
    }

    if ($verificationSection) {
        $releaseNotes += "## Runtime verification`n`n$verificationSection`n`n"
    }

    if ($installationSection) {
        $releaseNotes += "## Installation`n`n$installationSection`n`n"
    }
}

$releaseNotes += "## Integrity`n`nSHA-256:`n`n"
$releaseNotes += '```text'
$releaseNotes += "`n$sha256`n"
$releaseNotes += '```'
$releaseNotes += "`n"
Set-Content -LiteralPath $notesPath -Value $releaseNotes -Encoding utf8

$published = $false
$releaseUrl = $null

if ($Publish) {
    Assert-Command -Name 'gh'

    if ([string]::IsNullOrWhiteSpace($Repository)) {
        throw 'Repository was not supplied and GITHUB_REPOSITORY is not set.'
    }

    if ($branch -ne 'main') {
        throw "Publishing requires main. Current branch: $branch"
    }

    $existingRelease = & gh release view $tag --repo $Repository --json url 2>$null
    if ($LASTEXITCODE -eq 0) {
        throw "GitHub release $tag already exists."
    }

    $arguments = @(
        'release', 'create', $tag,
        $archivePath,
        $checksumPath,
        '--repo', $Repository,
        '--target', $commit,
        '--title', "Adaptive Auto Connector v$version",
        '--notes-file', $notesPath
    )

    if ($Draft) {
        $arguments += '--draft'
    }

    if ($Prerelease) {
        $arguments += '--prerelease'
    }

    & gh @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub release publication failed for $tag."
    }

    $releaseJson = & gh release view $tag --repo $Repository --json tagName,name,url,isDraft,isPrerelease,assets
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify GitHub release $tag."
    }

    $release = $releaseJson | ConvertFrom-Json
    if ($release.tagName -ne $tag) {
        throw 'Published release tag verification failed.'
    }

    $assetNames = @($release.assets | ForEach-Object { $_.name })
    if ($archiveName -notin $assetNames) {
        throw "Published release is missing $archiveName."
    }

    if ((Split-Path -Leaf $checksumPath) -notin $assetNames) {
        throw "Published release is missing $(Split-Path -Leaf $checksumPath)."
    }

    $published = $true
    $releaseUrl = [string]$release.url
}

$result = [pscustomobject]@{
    Success          = $true
    Version          = $version
    Tag              = $tag
    ProjectRoot      = $repoRoot
    Branch           = $branch
    Commit           = $commit
    ArchivePath      = $archivePath
    ChecksumPath     = $checksumPath
    ReleaseNotesPath = $notesPath
    SHA256           = $sha256
    Published        = $published
    ReleaseUrl       = $releaseUrl
}

$result | Format-List
