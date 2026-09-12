[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Archive,
    [string]$AsmArchive,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Read-only: no extraction, packaging, installation or publication.
$record = Get-Content -LiteralPath (Join-Path $ProjectRoot 'tests/test7-package.json') -Raw | ConvertFrom-Json
$archiveHash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($archiveHash -cne $record.sha256) {
    throw "AAC archive differs from the runtime-validated test7 package: $archiveHash"
}
if ($AsmArchive) {
    $asmHash = (Get-FileHash -LiteralPath $AsmArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($asmHash -cne $record.testedAsmSha256) {
        throw "ASM archive differs from the original test20 package used in validation: $asmHash"
    }
}

$source = (Resolve-Path -LiteralPath (Join-Path $ProjectRoot "mods-unpacked/$($record.modFolder)")).Path
$sourcePrefix = $source.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
$zipPrefix = "mods-unpacked/$($record.modFolder)/"
$expectedFiles = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force) {
    $relative = $file.FullName.Substring($sourcePrefix.Length).Replace('\', '/')
    $expectedFiles.Add($zipPrefix + $relative, $file.FullName)
}
if ($expectedFiles.Count -ne $record.fileCount) {
    throw "Source tree has $($expectedFiles.Count) files; validated test7 has $($record.fileCount)."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Archive).Path)
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        if (-not $seen.Add($entry.FullName)) { throw "Duplicate archive file: $($entry.FullName)" }
        if (-not $expectedFiles.ContainsKey($entry.FullName)) { throw "Unexpected archive file: $($entry.FullName)" }
        $stream = $entry.Open()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $entryHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $hasher.Dispose()
            $stream.Dispose()
        }
        $sourceHash = (Get-FileHash -LiteralPath $expectedFiles[$entry.FullName] -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($entryHash -cne $sourceHash) { throw "Source differs byte-for-byte from validated package: $($entry.FullName)" }
    }
    if ($seen.Count -ne $record.fileCount) { throw "Archive file count differs from validated test7." }

    $reader = [IO.StreamReader]::new($zip.GetEntry($zipPrefix + 'manifest.json').Open())
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
    if ($manifest.version_number -cne $record.manifestVersion) { throw 'Unexpected manifest version.' }
}
finally { $zip.Dispose() }

[pscustomobject]@{
    Build = $record.build
    FilesVerified = $seen.Count
    SHA256 = $archiveHash
    SourceMatchesByteForByte = $true
    TestedAsmArchiveVerified = [bool]$AsmArchive
    Published = $false
}
