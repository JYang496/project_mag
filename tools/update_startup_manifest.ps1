[CmdletBinding(DefaultParameterSetName = 'Check')]
param(
    [Parameter(ParameterSetName = 'Check')][switch]$Check,
    [Parameter(Mandatory, ParameterSetName = 'Write')][switch]$Write,
    [string[]]$Domain = @(),
    [string]$GodotPath,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$infrastructureRoot = Join-Path $repoRoot 'tests/infrastructure'
$manifestPath = Join-Path $repoRoot 'data/startup/startup_resource_manifest.json'
$auditScript = 'res://tests/headless/startup/run_startup_resource_manifest_audit_headless.gd'
Import-Module (Join-Path $infrastructureRoot 'StartupManifest.psm1') -Force
Import-Module (Join-Path $infrastructureRoot 'TestWorker.psm1') -Force

$changes = @()
if ($Write) {
    $changes = @(Update-StartupManifestPaths `
        -RepoRoot $repoRoot `
        -ManifestPath $manifestPath `
        -Domain $Domain)
}

$structure = Test-StartupManifestStructure `
    -RepoRoot $repoRoot `
    -ManifestPath $manifestPath `
    -Domain $Domain

$semantic = [pscustomobject]@{
    ok = $false
    exit_code = 2
    output = ''
}
if ([bool]$structure.ok) {
    $resolvedGodotPath = Resolve-GodotExecutable -GodotPath $GodotPath
    $arguments = @('--headless', '--path', $repoRoot, '--script', $auditScript, '--quit-after', '5')
    if ($Domain.Count -gt 0) {
        $arguments += '--'
        foreach ($domainName in $Domain) {
            $arguments += @('--domain', $domainName)
        }
    }
    $output = & $resolvedGodotPath @arguments 2>&1
    $exitCode = [int]$LASTEXITCODE
    $outputText = (@($output) | ForEach-Object { $_.ToString() }) -join "`n"
    $semantic = [pscustomobject]@{
        ok = $exitCode -eq 0 -and $outputText -match 'STARTUP_MANIFEST_AUDIT: PASS'
        exit_code = $exitCode
        output = $outputText
    }
}

$result = [pscustomobject]@{
    ok = [bool]$structure.ok -and [bool]$semantic.ok
    mode = if ($Write) { 'write' } else { 'check' }
    domains = @($Domain)
    changes = @($changes)
    structure = $structure
    semantic = $semantic
}

if ($Json) {
    $result | ConvertTo-Json -Depth 10
} else {
    Write-Output "Startup manifest mode: $($result.mode.ToUpperInvariant())"
    foreach ($change in $changes) {
        Write-Output "$($change.domain): $($change.count) resources"
        foreach ($path in $change.added) { Write-Output "  + $path" }
        foreach ($path in $change.removed) { Write-Output "  - $path" }
    }
    foreach ($catalog in $structure.catalogs) {
        Write-Output "$($catalog.domain): declared=$($catalog.declared_count) actual=$($catalog.actual_count)"
    }
    foreach ($errorMessage in $structure.errors) {
        Write-Output "ERROR: $errorMessage"
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$semantic.output)) {
        Write-Output $semantic.output
    }
}

if (-not [bool]$result.ok) {
    exit 2
}
exit 0
