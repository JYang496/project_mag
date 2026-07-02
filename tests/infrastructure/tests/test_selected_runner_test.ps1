[CmdletBinding()]
param([string]$GodotPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infrastructureRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $infrastructureRoot)
$runScript = Join-Path $infrastructureRoot 'run_selected_tests.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'project_mag-selected-runner-selftest-{0}' -f [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$manifestPath = Join-Path $tempRoot 'manifest.json'
$sourceMapPath = Join-Path $tempRoot 'source_domain_map.json'
$outputRoot = Join-Path $tempRoot 'worker'

$manifest = [ordered]@{
    schema_version = 1
    catalog_status = 'self-test'
    tests = @(
        [ordered]@{
            id = 'infrastructure.worker_success'
            entry_type = 'script'
            path = 'res://tests/infrastructure/fixtures/worker_success.gd'
            domain = 'infrastructure'
            dependency_domains = @()
            parallel_safe = $true
            writes_user_data = $false
            timeout_seconds = 30
        }
    )
}
$sourceMap = [ordered]@{
    schema_version = 1
    full_fallback = [ordered]@{
        exact_paths = @()
        prefixes = @()
    }
    ignored_exact_paths = @()
    ignored_prefixes = @('docs/')
    domain_rules = @(
        [ordered]@{
            prefix = 'tests/infrastructure/fixtures/'
            domain = 'infrastructure'
            certainty = 'known'
        }
    )
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
$sourceMap | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $sourceMapPath

$arguments = @(
    '-NoProfile',
    '-File', $runScript,
    '-ChangedPath', 'tests/infrastructure/fixtures/worker_success.gd',
    '-ManifestPath', $manifestPath,
    '-SourceMapPath', $sourceMapPath,
    '-GodotPath', $GodotPath,
    '-Jobs', '1',
    '-OutputRoot', $outputRoot,
    '-SkipCheckOnly',
    '-Json'
)
$output = & pwsh @arguments
if ($LASTEXITCODE -ne 0) {
    Write-Error "run_selected_tests.ps1 exited with $LASTEXITCODE. Output:`n$($output -join "`n")"
    exit 1
}
$result = ($output -join "`n") | ConvertFrom-Json
if ($result.selection.mode -ne 'affected') {
    Write-Error "Expected affected selection, got '$($result.selection.mode)'."
    exit 1
}
if (@($result.selection.tests).Count -ne 1 -or $result.selection.tests[0].id -ne 'infrastructure.worker_success') {
    Write-Error "Expected only infrastructure.worker_success to be selected."
    exit 1
}
if ($result.worker.passed -ne 1 -or $result.worker.failed -ne 0 -or $result.worker.errors -ne 0) {
    Write-Error "Expected selected worker run to pass. Output:`n$($output -join "`n")"
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $outputRoot 'summary.json') -PathType Leaf)) {
    Write-Error 'Expected worker summary.json to be written.'
    exit 1
}

Write-Output 'Selected runner self-test: PASS'
Write-Output "Retained run artifacts: $tempRoot"
exit 0
