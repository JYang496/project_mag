[CmdletBinding()]
param(
    [string]$BaseRef,
    [string[]]$ChangedPath,
    [string[]]$IncludeTest = @(),
    [string]$ManifestPath,
    [string]$SourceMapPath,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TestSelection.psm1') -Force

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot 'test_manifest.json'
}
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) {
    $SourceMapPath = Join-Path $PSScriptRoot 'source_domain_map.json'
}

function Get-GitChangedPath {
    param([string]$ComparisonBase)

    $paths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $commands = @(
        @('diff', '--name-only', '--diff-filter=ACMRTUXB'),
        @('diff', '--cached', '--name-only', '--diff-filter=ACMRTUXB'),
        @('ls-files', '--others', '--exclude-standard')
    )
    if (-not [string]::IsNullOrWhiteSpace($ComparisonBase)) {
        $commands += ,@('diff', '--name-only', '--diff-filter=ACMRTUXB', "$ComparisonBase...HEAD")
    }
    foreach ($arguments in $commands) {
        $output = & git @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "git $($arguments -join ' ') failed with exit code $LASTEXITCODE."
        }
        foreach ($path in @($output)) {
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                [void]$paths.Add($path)
            }
        }
    }
    return @($paths | Sort-Object)
}

$effectiveChangedPath = if ($PSBoundParameters.ContainsKey('ChangedPath')) {
    @($ChangedPath)
} else {
    @(Get-GitChangedPath -ComparisonBase $BaseRef)
}

$selection = Select-AffectedTests `
    -ChangedPath $effectiveChangedPath `
    -IncludeTest $IncludeTest `
    -ManifestPath $ManifestPath `
    -SourceMapPath $SourceMapPath

if ($Json) {
    $selection | ConvertTo-Json -Depth 8
    return
}

Write-Output "Selection mode: $($selection.mode)"
Write-Output "Catalog status: $($selection.catalog_status)"
Write-Output "Changed paths: $($selection.changed_paths.Count)"
Write-Output "Domains: $(if ($selection.domains.Count -gt 0) { $selection.domains -join ', ' } else { '(none)' })"
Write-Output 'Reasons:'
foreach ($reason in $selection.reasons) {
    Write-Output "  - $reason"
}
Write-Output "Tests ($($selection.tests.Count)):"
foreach ($test in $selection.tests) {
    Write-Output "  - $($test.id) [$($test.entry_type)] $($test.path)"
}
