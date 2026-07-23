[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infrastructureRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $infrastructureRoot 'StartupManifest.psm1') -Force
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'project-mag-startup-manifest-selftest-{0}' -f [guid]::NewGuid().ToString('N')
)
$dataRoot = Join-Path $tempRoot 'data/example'
New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
$manifestPath = Join-Path $tempRoot 'manifest.json'

try {
    Set-Content -LiteralPath (Join-Path $dataRoot 'beta.tres') -Value '[resource]'
    Set-Content -LiteralPath (Join-Path $dataRoot 'alpha.tres') -Value '[resource]'
    $manifest = [ordered]@{
        schema_version = 1
        runtime_consumed = $true
        runtime_consumed_domains = @('example')
        ordering = 'manifest_paths_sorted'
        catalogs = @(
            [ordered]@{
                domain = 'example'
                prepare_phase = 'world'
                directory = 'res://data/example/'
                extension = '.tres'
                expected_type = 'Resource'
                id_property = ''
                paths = @('res://data/example/alpha.tres')
            }
        )
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath

    $stale = Test-StartupManifestStructure -RepoRoot $tempRoot -ManifestPath $manifestPath
    if ([bool]$stale.ok -or -not [bool]($stale.errors -match 'unlisted resource')) {
        throw "Expected an unlisted-resource failure, got: $($stale.errors -join '; ')"
    }

    $changes = @(Update-StartupManifestPaths -RepoRoot $tempRoot -ManifestPath $manifestPath)
    if ($changes.Count -ne 1 -or $changes[0].added -cnotcontains 'res://data/example/beta.tres') {
        throw 'Expected updater to report beta.tres as added.'
    }
    $updated = Test-StartupManifestStructure -RepoRoot $tempRoot -ManifestPath $manifestPath
    if (-not [bool]$updated.ok) {
        throw "Expected updated manifest to pass: $($updated.errors -join '; ')"
    }
    $updatedManifest = Read-StartupManifest -ManifestPath $manifestPath
    $expectedPaths = @(
        'res://data/example/alpha.tres',
        'res://data/example/beta.tres'
    )
    if ((@($updatedManifest.catalogs[0].paths) -join "`n") -cne ($expectedPaths -join "`n")) {
        throw 'Expected updater to write stable ordinal path order.'
    }

    $updatedManifest.runtime_consumed_domains = @('example', 'ghost')
    $updatedManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    $drifted = Test-StartupManifestStructure -RepoRoot $tempRoot -ManifestPath $manifestPath
    if ([bool]$drifted.ok -or -not [bool]($drifted.errors -match 'exactly match catalog domains')) {
        throw 'Expected runtime domain drift to fail validation.'
    }

    Write-Output 'Startup manifest infrastructure self-test: PASS'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
